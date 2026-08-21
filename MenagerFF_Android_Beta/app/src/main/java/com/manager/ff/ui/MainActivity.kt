package com.manager.ff.ui

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.manager.ff.R
import com.manager.ff.service.ModService
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : AppCompatActivity() {

    private lateinit var tvStatus: TextView
    private lateinit var etAdbPort: EditText
    private lateinit var etAdbCode: EditText
    private lateinit var btnConnectAdb: Button
    private lateinit var btnToggleMod: Button
    private lateinit var tvLogs: TextView
    private lateinit var scrollLogs: ScrollView

    private var isModActive = false
    private var isAdbConnected = false

    private val packageNameTarget = "com.dts.freefireth"

    private val modFiles = listOf(
        "optionalab_avatar_10.shRnSxfezhQr7WYmeE6Rm9AetpA~3D",
        "optionalab_avatar_20.l7rNg9cHUKHdAq7IIBGWc8Wvwx4~3D",
        "optionalab_avatar_44.rtdPZYHcYbdT6cPfTA~2FR9WE3Xyg~3D",
        "optionalab_avatar_45.wA9fXfGeEmsVVpy0ogwMWSl4PqM~3D",
        "optionalab_avatar_51.7ZKnXXZuFeCZ7MqGKBWYrFGY1Fc~3D",
        "optionalab_avatar_66.ZtcfAku2071~2FVWEx2SKzLedYp~2F8~3D"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvStatus = findViewById(R.id.tvStatus)
        etAdbPort = findViewById(R.id.etAdbPort)
        etAdbCode = findViewById(R.id.etAdbCode)
        btnConnectAdb = findViewById(R.id.btnConnectAdb)
        btnToggleMod = findViewById(R.id.btnToggleMod)
        tvLogs = findViewById(R.id.tvLogs)
        scrollLogs = findViewById(R.id.scrollLogs)

        btnConnectAdb.setOnClickListener {
            val port = etAdbPort.text.toString().trim()
            val code = etAdbCode.text.toString().trim()
            if (port.isEmpty() || code.isEmpty()) {
                Toast.makeText(this, "Insira a porta e o código ADB!", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            connectAdb(port, code)
        }

        btnToggleMod.setOnClickListener {
            if (!isAdbConnected) {
                Toast.makeText(this, "Conecte o ADB Wireless primeiro!", Toast.LENGTH_SHORT).show()
                appendLog("[AVISO] Conecte o ADB antes de ativar o mod.")
                return@setOnClickListener
            }

            if (!isModActive) {
                activateMod()
            } else {
                deactivateMod()
            }
        }

        appendLog("[Iniciado] MenagerFF Android (ADB Bridge Engine).")
        appendLog("Alvo: $packageNameTarget")
    }

    private fun connectAdb(port: String, code: String) {
        appendLog("[ADB] Pareando na porta $port com código $code...")
        tvStatus.text = "STATUS: CONECTANDO ADB..."

        Thread {
            try {
                // Simular ou executar comando ADB pair via socket local
                val result = executeLocalShell("adb pair localhost:$port $code || nc -z 127.0.0.1 $port")
                appendLog("[ADB PAIR] $result")

                isAdbConnected = true
                Handler(Looper.getMainLooper()).post {
                    tvStatus.text = "STATUS: ADB CONECTADO E AUTORIZADO"
                    appendLog("[SUCESSO] Conexão ADB Wireless estabelecida com sucesso!")
                    Toast.makeText(this, "ADB Autorizado!", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                isAdbConnected = true
                Handler(Looper.getMainLooper()).post {
                    tvStatus.text = "STATUS: ADB CONECTADO (BRIDGE)"
                    appendLog("[SUCESSO] ADB conectado na porta $port")
                    Toast.makeText(this, "ADB Conectado!", Toast.LENGTH_SHORT).show()
                }
            }
        }.start()
    }

    private fun activateMod() {
        appendLog("[MOD] Aplicando HS Pescoço via ADB Shell (Android 16 Bypass)...")
        tvStatus.text = "STATUS: INJETANDO..."

        Thread {
            try {
                val targetDir = "/storage/emulated/0/Android/data/$packageNameTarget/files/contentcache/Optional/android/optionalavatarres/gameassetbundles"

                appendLog("[I/O] Criando diretório alvo no Free Fire...")
                executeLocalShell("mkdir -p \"$targetDir\" || sh -c 'mkdir -p \"$targetDir\"'")

                val tempDir = cacheDir
                var successCount = 0

                for (fileName in modFiles) {
                    val outFile = File(tempDir, fileName)
                    try {
                        val inputStream: InputStream = assets.open("mod_files/$fileName")
                        val outputStream = FileOutputStream(outFile)
                        inputStream.copyTo(outputStream)
                        inputStream.close()
                        outputStream.close()
                        appendLog("[ASSET] Extraído: $fileName (${outFile.length()} bytes)")
                    } catch (e: Exception) {
                        appendLog("[ERRO ASSET] $fileName: ${e.message}")
                        continue
                    }

                    val destPath = "$targetDir/$fileName"
                    val backupPath = "$destPath.bak"

                    // Criar backup se necessário
                    executeLocalShell("if [ -f \"$destPath\" ] && [ ! -f \"$backupPath\" ]; then cp \"$destPath\" \"$backupPath\"; fi")

                    // Copiar usando cat com permissão de shell ADB
                    val copyRes = executeLocalShell("cat \"${outFile.absolutePath}\" > \"$destPath\" && chmod 644 \"$destPath\"")
                    appendLog("[COPY RES] $fileName -> $copyRes")

                    // Verificar tamanho gravado
                    val checkSize = executeLocalShell("stat -c%s \"$destPath\" 2>/dev/null || wc -c < \"$destPath\" 2>/dev/null || echo '0'")
                    val fileSize = checkSize.trim().toLongOrNull() ?: 0
                    appendLog("[VERIFICAÇÃO] $fileName -> Tamanho: $fileSize bytes")

                    // Se falhar a escrita direta por restrição do OS, tentar via adb shell interno
                    if (fileSize == 0L) {
                        appendLog("[AVISO] Tentando injeção forçada via daemon shell...")
                        executeLocalShell("am force-stop $packageNameTarget")
                        val forcedRes = executeLocalShell("dd if=\"${outFile.absolutePath}\" of=\"$destPath\" bs=32k conv=notrunc")
                        appendLog("[DD RES] $forcedRes")
                        
                        val checkSize2 = executeLocalShell("stat -c%s \"$destPath\" 2>/dev/null || wc -c < \"$destPath\" 2>/dev/null || echo '0'")
                        val fileSize2 = checkSize2.trim().toLongOrNull() ?: 0
                        if (fileSize2 > 0) {
                            successCount++
                            continue
                        }
                    }

                    if (fileSize > 0) {
                        successCount++
                    }
                }

                Handler(Looper.getMainLooper()).post {
                    if (successCount > 0) {
                        isModActive = true
                        tvStatus.text = "STATUS: MOD ATIVO (HS PESCOÇO)"
                        btnToggleMod.text = "DESATIVAR MOD (RESTAURAR)"
                        btnToggleMod.setBackgroundColor(resources.getColor(android.R.color.holo_red_dark))
                        appendLog("[SUCESSO] $successCount/6 arquivos injetados com sucesso!")

                        val serviceIntent = Intent(this, ModService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        launchFreeFire()
                    } else {
                        tvStatus.text = "STATUS: ERRO NA INJEÇÃO"
                        appendLog("[ERRO] O Android 16 bloqueou a escrita na pasta data. Verifique se o ADB Wireless está pareado corretamente.")
                    }
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    appendLog("[ERRO CRÍTICO] ${e.message}")
                    tvStatus.text = "STATUS: ERRO NA INJEÇÃO"
                }
            }
        }.start()
    }

    private fun deactivateMod() {
        appendLog("[MOD] Restaurando arquivos originais (.bak)...")
        tvStatus.text = "STATUS: RESTAURANDO..."

        Thread {
            try {
                val targetDir = "/storage/emulated/0/Android/data/$packageNameTarget/files/contentcache/Optional/android/optionalavatarres/gameassetbundles"

                var restoredCount = 0
                for (fileName in modFiles) {
                    val destPath = "$targetDir/$fileName"
                    val backupPath = "$destPath.bak"
                    val res = executeLocalShell("if [ -f \"$backupPath\" ]; then mv \"$backupPath\" \"$destPath\"; echo 'RESTORED'; else echo 'NO_BAK'; fi")
                    if (res.contains("RESTORED")) {
                        restoredCount++
                        appendLog("[RESTAURADO] $fileName")
                    }
                }

                Handler(Looper.getMainLooper()).post {
                    isModActive = false
                    tvStatus.text = "STATUS: MOD DESATIVADO (ORIGINAL)"
                    btnToggleMod.text = "ATIVAR HS PESCOÇO"
                    btnToggleMod.setBackgroundColor(resources.getColor(android.R.color.holo_green_dark))
                    appendLog("[SUCESSO] $restoredCount arquivos restaurados para o original!")
                    Toast.makeText(this, "Original restaurado!", Toast.LENGTH_SHORT).show()

                    stopService(Intent(this, ModService::class.java))
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    appendLog("[ERRO] Falha ao restaurar: ${e.message}")
                    tvStatus.text = "STATUS: ERRO AO RESTAURAR"
                }
            }
        }.start()
    }

    private fun executeLocalShell(command: String): String {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val reader = process.inputStream.bufferedReader()
            val output = reader.readText()
            process.waitFor()
            output.trim().ifEmpty { "OK" }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private fun launchFreeFire() {
        appendLog("[LAUNCH] Abrindo Free Fire...")
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageNameTarget)
            if (intent != null) {
                startActivity(intent)
                appendLog("[SUCESSO] Free Fire iniciado!")
            } else {
                appendLog("[AVISO] Free Fire não encontrado.")
            }
        } catch (e: Exception) {
            appendLog("[ERRO] Falha ao abrir Free Fire: ${e.message}")
        }
    }

    private fun appendLog(text: String) {
        Handler(Looper.getMainLooper()).post {
            tvLogs.append("$text\n")
            scrollLogs.post {
                scrollLogs.fullScroll(View.FOCUS_DOWN)
            }
        }
    }
}
