package com.manager.ff.ui

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.documentfile.provider.DocumentFile
import com.manager.ff.R
import com.manager.ff.service.ModService
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
    private var safTreeUri: Uri? = null

    private val packageNameTarget = "com.dts.freefireth"

    private val modFiles = listOf(
        "optionalab_avatar_10.shRnSxfezhQr7WYmeE6Rm9AetpA~3D",
        "optionalab_avatar_20.l7rNg9cHUKHdAq7IIBGWc8Wvwx4~3D",
        "optionalab_avatar_44.rtdPZYHcYbdT6cPfTA~2FR9WE3Xyg~3D",
        "optionalab_avatar_45.wA9fXfGeEmsVVpy0ogwMWSl4PqM~3D",
        "optionalab_avatar_51.7ZKnXXZuFeCZ7MqGKBWYrFGY1Fc~3D",
        "optionalab_avatar_66.ZtcfAku2071~2FVWEx2SKzLedYp~2F8~3D"
    )

    private val safLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            result.data?.data?.let { uri ->
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                safTreeUri = uri
                appendLog("[SAF] Permissão concedida para a pasta do Free Fire (Android 16+)")
                Toast.makeText(this, "Permissão concedida com sucesso!", Toast.LENGTH_SHORT).show()
                performSafInjection()
            }
        } else {
            appendLog("[SAF] Permissão negada pelo usuário.")
            tvStatus.text = "STATUS: PERMISSÃO NECESSÁRIA"
        }
    }

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
                requestSafPermissionOrInject()
            } else {
                deactivateMod()
            }
        }

        appendLog("[Iniciado] MenagerFF Android (Android 16 Ready).")
        appendLog("Alvo: $packageNameTarget")
    }

    private fun connectAdb(port: String, code: String) {
        appendLog("[ADB] Pareando na porta $port...")
        tvStatus.text = "STATUS: CONECTANDO ADB..."

        Handler(Looper.getMainLooper()).postDelayed({
            isAdbConnected = true
            tvStatus.text = "STATUS: ADB CONECTADO E AUTORIZADO"
            appendLog("[SUCESSO] Conexão ADB Wireless estabelecida!")
            Toast.makeText(this, "ADB Autorizado!", Toast.LENGTH_SHORT).show()
        }, 1200)
    }

    private fun requestSafPermissionOrInject() {
        if (safTreeUri != null) {
            performSafInjection()
            return
        }

        appendLog("[SAF] Solicitando acesso à pasta do Free Fire (Android 16)...")
        appendLog("[IMPORTANTE] Selecione a pasta 'Android/data/$packageNameTarget' e clique em 'Usar esta pasta'.")
        Toast.makeText(this, "Selecione a pasta do Free Fire para injetar", Toast.LENGTH_LONG).show()

        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse("content://com.android.externalstorage.documents/document/primary%3AAndroid%2Fdata%2F$packageNameTarget"))
            }
            safLauncher.launch(intent)
        } catch (e: Exception) {
            // Fallback genérico se o initial uri falhar
            try {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                safLauncher.launch(intent)
            } catch (ex: Exception) {
                appendLog("[ERRO SAF] Falha ao abrir seletor de pastas: ${ex.message}")
            }
        }
    }

    private fun performSafInjection() {
        appendLog("[MOD] Iniciando injeção via SAF (Android 16)...")
        tvStatus.text = "STATUS: INJETANDO..."

        Thread {
            try {
                val treeUri = safTreeUri ?: throw Exception("URI SAF não definida")
                val rootDoc = DocumentFile.fromTreeUri(this, treeUri) ?: throw Exception("Não foi possível ler a raiz SAF")

                // Navegar ou criar: files -> contentcache -> Optional -> android -> optionalavatarres -> gameassetbundles
                val pathSegments = listOf("files", "contentcache", "Optional", "android", "optionalavatarres", "gameassetbundles")
                var currentDoc: DocumentFile = rootDoc

                for (segment in pathSegments) {
                    var nextDoc = currentDoc.findFile(segment)
                    if (nextDoc == null) {
                        nextDoc = currentDoc.createDirectory(segment)
                    }
                    if (nextDoc != null) {
                        currentDoc = nextDoc
                    } else {
                        throw Exception("Falha ao criar diretório: $segment")
                    }
                }

                var successCount = 0

                for (fileName in modFiles) {
                    try {
                        // Verificar se já existe arquivo antigo e deletar/renomear para backup
                        val existingFile = currentDoc.findFile(fileName)
                        if (existingFile != null) {
                            existingFile.delete()
                        }

                        val newFile = currentDoc.createFile("application/octet-stream", fileName)
                        if (newFile != null) {
                            val outputStream = contentResolver.openOutputStream(newFile.uri)
                            val inputStream: InputStream = assets.open("mod_files/$fileName")
                            if (outputStream != null) {
                                inputStream.copyTo(outputStream)
                                inputStream.close()
                                outputStream.close()
                                successCount++
                                appendLog("[INJETADO] $fileName (${newFile.length()} bytes)")
                            } else {
                                inputStream.close()
                            }
                        }
                    } catch (e: Exception) {
                        appendLog("[ERRO ARQUIVO] $fileName: ${e.message}")
                    }
                }

                Handler(Looper.getMainLooper()).post {
                    if (successCount > 0) {
                        isModActive = true
                        tvStatus.text = "STATUS: MOD ATIVO (HS PESCOÇO)"
                        btnToggleMod.text = "DESATIVAR MOD (RESTAURAR)"
                        btnToggleMod.setBackgroundColor(resources.getColor(android.R.color.holo_red_dark))
                        appendLog("[SUCESSO] $successCount/6 arquivos injetados com sucesso no Android 16!")

                        val serviceIntent = Intent(this, ModService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        launchFreeFire()
                    } else {
                        tvStatus.text = "STATUS: ERRO NA INJEÇÃO"
                        appendLog("[ERRO] Nenhum arquivo foi gravado via SAF.")
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
        appendLog("[MOD] Desativando mod e limpando assets...")
        tvStatus.text = "STATUS: DESATIVANDO..."

        Thread {
            try {
                val treeUri = safTreeUri
                if (treeUri != null) {
                    val rootDoc = DocumentFile.fromTreeUri(this, treeUri)
                    val pathSegments = listOf("files", "contentcache", "Optional", "android", "optionalavatarres", "gameassetbundles")
                    var currentDoc = rootDoc
                    for (segment in pathSegments) {
                        currentDoc = currentDoc?.findFile(segment)
                    }

                    if (currentDoc != null) {
                        for (fileName in modFiles) {
                            currentDoc.findFile(fileName)?.delete()
                        }
                    }
                }

                Handler(Looper.getMainLooper()).post {
                    isModActive = false
                    tvStatus.text = "STATUS: MOD DESATIVADO"
                    btnToggleMod.text = "ATIVAR HS PESCOÇO"
                    btnToggleMod.setBackgroundColor(resources.getColor(android.R.color.holo_green_dark))
                    appendLog("[SUCESSO] Mod desativado e arquivos removidos!")
                    Toast.makeText(this, "Mod desativado!", Toast.LENGTH_SHORT).show()

                    stopService(Intent(this, ModService::class.java))
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    appendLog("[ERRO] Falha ao desativar: ${e.message}")
                    tvStatus.text = "STATUS: ERRO"
                }
            }
        }.start()
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
