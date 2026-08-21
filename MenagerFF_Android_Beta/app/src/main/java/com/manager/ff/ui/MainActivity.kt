package com.manager.ff.ui

import android.content.Intent
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.manager.ff.R
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var logConsole: TextView
    private lateinit var btnPair: Button
    private lateinit var btnInject: Button
    private lateinit var btnRestore: Button

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

        statusText = findViewById(R.id.statusText)
        logConsole = findViewById(R.id.logConsole)
        btnPair = findViewById(R.id.btnPair)
        btnInject = findViewById(R.id.btnInject)
        btnRestore = findViewById(R.id.btnRestore)

        appendLog("MenagerFF Android Beta [Real I/O Engine] iniciado.")
        appendLog("Alvo: com.dts.freefireth (Free Fire Normal)")
        appendLog("Modo: Injeção Real de 6 Assets de Avatar (HS Pescoço)")

        btnPair.setOnClickListener {
            appendLog("Iniciando assistente de pareamento Shizuku / ADB...")
            statusText.text = "Status: Abra as Opções do Desenvolvedor > Depuração por Wi-Fi"
            try {
                val intent = packageManager.getLaunchIntentForPackage("moe.shizuku.manager")
                if (intent != null) {
                    startActivity(intent)
                    appendLog("[INFO] Shizuku aberto com sucesso.")
                } else {
                    appendLog("[AVISO] Shizuku não encontrado. Conecte via ADB Wireless.")
                    statusText.text = "Status: Shizuku não encontrado!"
                }
            } catch (e: Exception) {
                appendLog("[ERRO] Falha ao abrir Shizuku: ${e.message}")
            }
        }

        btnInject.setOnClickListener {
            appendLog("=== INICIANDO INJEÇÃO REAL DE ARQUIVOS ===")
            statusText.text = "Status: Gravando arquivos do mod no Free Fire..."

            Thread {
                executeRealInjection()
            }.start()
        }

        btnRestore.setOnClickListener {
            appendLog("=== INICIANDO RESTAURAÇÃO DE BACKUP ===")
            statusText.text = "Status: Restaurando originais (.bak)..."

            Thread {
                executeRealRestore()
            }.start()
        }
    }

    private fun executeRealInjection() {
        try {
            val targetPath = "/storage/emulated/0/Android/data/$packageNameTarget/files/contentcache/Optional/android/optionalavatarres/gameassetbundles"
            
            // 1. Criar diretório via shell/ADB
            appendLog("[I/O] Criando diretório Optional no Free Fire...")
            executeShell("mkdir -p \"$targetPath\"")

            val targetDir = File(targetPath)
            if (!targetDir.exists()) {
                appendLog("[AVISO] Diretório alvo não criado diretamente. Tentando via shell...")
            }

            // 2. Extrair arquivos dos assets para cache e copiar para o destino
            var successCount = 0
            for (fileName in modFiles) {
                val assetFileName = "mod_files/$fileName"
                val destFile = File(targetDir, fileName)
                val backupFile = File(targetDir, "$fileName.bak")

                // Extrair dos assets para arquivo temporário
                val tempFile = File(cacheDir, fileName)
                val inputStream: InputStream = assets.open(assetFileName)
                val outputStream = FileOutputStream(tempFile)
                inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()

                // Criar backup se o original existe e não tem backup
                if (destFile.exists() && !backupFile.exists()) {
                    executeShell("cp \"${destFile.absolutePath}\" \"${backupFile.absolutePath}\"")
                    appendLog("[BACKUP] Original salvo: $fileName.bak")
                }

                // Copiar arquivo real do mod
                val cpResult = executeShell("cp \"${tempFile.absolutePath}\" \"${destFile.absolutePath}\"")
                executeShell("chmod 644 \"${destFile.absolutePath}\"")

                if (destFile.exists()) {
                    appendLog("[SUCESSO] Injetado: $fileName")
                    successCount++
                } else {
                    appendLog("[ERRO] Falha ao gravar: $fileName (Output: $cpResult)")
                }
            }

            Handler(Looper.getMainLooper()).post {
                if (successCount == modFiles.size) {
                    appendLog("=== INJEÇÃO CONCLUÍDA COM SUCESSO! ===")
                    statusText.text = "Status: Mod Ativo! Abrindo Free Fire..."
                    launchFreeFire()
                } else {
                    appendLog("[AVISO] Injeção parcial ($successCount/${modFiles.size}). Verifique permissões ADB.")
                    statusText.text = "Status: Injeção concluída com avisos."
                }
            }

        } catch (e: Exception) {
            Handler(Looper.getMainLooper()).post {
                appendLog("[ERRO CRÍTICO] ${e.message}")
                statusText.text = "Status: Erro na injeção!"
            }
        }
    }

    private fun executeRealRestore() {
        try {
            val targetPath = "/storage/emulated/0/Android/data/$packageNameTarget/files/contentcache/Optional/android/optionalavatarres/gameassetbundles"
            val targetDir = File(targetPath)

            var restoredCount = 0
            for (fileName in modFiles) {
                val destFile = File(targetDir, fileName)
                val backupFile = File(targetDir, "$fileName.bak")

                if (backupFile.exists()) {
                    executeShell("mv \"${backupFile.absolutePath}\" \"${destFile.absolutePath}\"")
                    appendLog("[RESTAURADO] Original de volta: $fileName")
                    restoredCount++
                } else {
                    appendLog("[INFO] Nenhum backup encontrado para: $fileName")
                }
            }

            Handler(Looper.getMainLooper()).post {
                appendLog("=== RESTAURAÇÃO FINALIZADA ($restoredCount arquivos) ===")
                statusText.text = "Status: Restaurado para o original com sucesso."
            }
        } catch (e: Exception) {
            Handler(Looper.getMainLooper()).post {
                appendLog("[ERRO] Falha na restauração: ${e.message}")
                statusText.text = "Status: Erro na restauração!"
            }
        }
    }

    private fun executeShell(command: String): String {
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
        appendLog("[LAUNCH] Abrindo Free Fire automaticamente...")
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageNameTarget)
            if (intent != null) {
                startActivity(intent)
                appendLog("[SUCESSO] Free Fire iniciado!")
            } else {
                appendLog("[AVISO] Free Fire não encontrado.")
            }
        } catch (e: Exception) {
            appendLog("[ERRO] Falha ao iniciar Free Fire: ${e.message}")
        }
    }

    private fun appendLog(message: String) {
        Handler(Looper.getMainLooper()).post {
            val current = logConsole.text.toString()
            logConsole.text = "$current\n> $message"
        }
    }
}
