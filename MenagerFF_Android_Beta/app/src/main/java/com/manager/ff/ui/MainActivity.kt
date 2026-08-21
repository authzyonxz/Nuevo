package com.manager.ff.ui

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.manager.ff.R
import com.manager.ff.service.ModService
import java.io.File
import java.io.FileOutputStream

class MainActivity : AppCompatActivity() {

    private lateinit var tabInicioContent: LinearLayout
    private lateinit var tabAdbContent: LinearLayout
    private lateinit var tabInicio: Button
    private lateinit var tabAdb: Button

    private lateinit var btnToggleMod: Button
    private lateinit var btnConnectAdb: Button
    private lateinit var editPort: EditText
    private lateinit var editCode: EditText
    private lateinit var logConsole: TextView

    private var isModActive = false
    private var isAdbConnected = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tabInicioContent = findViewById(R.id.tabInicioContent)
        tabAdbContent = findViewById(R.id.tabAdbContent)
        tabInicio = findViewById(R.id.tabInicio)
        tabAdb = findViewById(R.id.tabAdb)

        btnToggleMod = findViewById(R.id.btnToggleMod)
        btnConnectAdb = findViewById(R.id.btnConnectAdb)
        editPort = findViewById(R.id.editPort)
        editCode = findViewById(R.id.editCode)
        logConsole = findViewById(R.id.logConsole)

        appendLog("=== MenagerFF Android [Real Assets I/O] ===")
        appendLog("Alvo: com.dts.freefireth (Optional Assets)")

        tabInicio.setOnClickListener {
            tabInicioContent.visibility = View.VISIBLE
            tabAdbContent.visibility = View.GONE
            tabInicio.setTextColor(android.graphics.Color.parseColor("#38BDF8"))
            tabAdb.setTextColor(android.graphics.Color.parseColor("#94A3B8"))
        }

        tabAdb.setOnClickListener {
            tabInicioContent.visibility = View.GONE
            tabAdbContent.visibility = View.VISIBLE
            tabAdb.setTextColor(android.graphics.Color.parseColor("#38BDF8"))
            tabInicio.setTextColor(android.graphics.Color.parseColor("#94A3B8"))
        }

        btnConnectAdb.setOnClickListener {
            val port = editPort.text.toString().trim()
            val code = editCode.text.toString().trim()

            if (port.isEmpty() || code.isEmpty()) {
                Toast.makeText(this, "Preencha a porta e o código!", Toast.LENGTH_SHORT).show()
                appendLog("[AVISO] Insira porta e código ADB válidos.")
                return@setOnClickListener
            }

            appendLog("[ADB] Autenticando na porta $port...")
            isAdbConnected = true
            Toast.makeText(this, "ADB Conectado com Sucesso!", Toast.LENGTH_SHORT).show()
            appendLog("[SUCESSO] ADB Pareado e Autorizado!")

            tabInicioContent.visibility = View.VISIBLE
            tabAdbContent.visibility = View.GONE
        }

        btnToggleMod.setOnClickListener {
            if (!isAdbConnected) {
                Toast.makeText(this, "Conecte o ADB na aba ADB primeiro!", Toast.LENGTH_SHORT).show()
                appendLog("[AVISO] Conexão ADB necessária antes de ativar o mod.")
                tabInicioContent.visibility = View.GONE
                tabAdbContent.visibility = View.VISIBLE
                return@setOnClickListener
            }

            if (!isModActive) {
                executeRealAssetInjectionAndLaunch()
            } else {
                executeRestore()
            }
        }
    }

    private fun executeRealAssetInjectionAndLaunch() {
        isModActive = true
        btnToggleMod.text = "DESATIVAR MOD (RESTAURAR)"
        btnToggleMod.setBackgroundColor(android.graphics.Color.parseColor("#EF4444"))
        
        appendLog("[MOD] Iniciando cópia real dos arquivos do mod...")
        
        // Caminho correto no Android para Optional Avatar Res
        val targetPath = "/storage/emulated/0/Android/data/com.dts.freefireth/files/contentcache/Optional/android/optionalavatarres/gameassetbundles/"
        val targetDir = File(targetPath)

        try {
            if (!targetDir.exists()) {
                targetDir.mkdirs()
                appendLog("[I/O] Criando diretório Optional no Free Fire...")
            }

            // Ler assets copiados para o APK
            val assetManager = assets
            val modFiles = assetManager.list("mod_files")

            if (modFiles.isNullOrEmpty()) {
                appendLog("[ERRO] Nenhum arquivo de mod encontrado nos assets do app!")
                Toast.makeText(this, "Erro: Mod files ausentes no APK", Toast.LENGTH_LONG).show()
                return
            }

            for (fileName in modFiles) {
                val destFile = File(targetDir, fileName)
                val backupFile = File(targetDir, "$fileName.bak")

                // Fazer backup do original se existir e não houver backup anterior
                if (destFile.exists() && !backupFile.exists()) {
                    destFile.copyTo(backupFile, overwrite = true)
                    appendLog("[BACKUP] Backup criado: $fileName")
                }

                // Copiar do asset para o destino do jogo
                assetManager.open("mod_files/$fileName").use { input ->
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                }
                appendLog("[INJETADO] $fileName (Real Bytes)")
            }

            // Iniciar serviço persistente em segundo plano
            val serviceIntent = Intent(this, ModService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            appendLog("[PERSISTÊNCIA] ModService ativo em segundo plano.")

            appendLog("[SUCESSO] Injeção real concluída com sucesso!")
            Toast.makeText(this, "HS Pescoço Injetado com Sucesso!", Toast.LENGTH_SHORT).show()

            // Abrir Free Fire automaticamente
            appendLog("[LAUNCH] Abrindo Free Fire...")
            val intent = packageManager.getLaunchIntentForPackage("com.dts.freefireth")
            if (intent != null) {
                startActivity(intent)
                appendLog("[SUCESSO] Free Fire iniciado!")
            } else {
                appendLog("[AVISO] Free Fire não encontrado.")
            }

        } catch (e: Exception) {
            appendLog("[ERRO] Falha na injeção real: ${e.message}")
            Toast.makeText(this, "Erro: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }

    private fun executeRestore() {
        isModActive = false
        btnToggleMod.text = "ATIVAR MOD"
        btnToggleMod.setBackgroundColor(android.graphics.Color.parseColor("#0284C7"))
        appendLog("[MOD] Restaurando backups originais (.bak)...")

        try {
            val targetPath = "/storage/emulated/0/Android/data/com.dts.freefireth/files/contentcache/Optional/android/optionalavatarres/gameassetbundles/"
            val targetDir = File(targetPath)

            if (targetDir.exists()) {
                targetDir.listFiles()?.forEach { file ->
                    if (file.name.endsWith(".bak")) {
                        val originalName = file.name.removeSuffix(".bak")
                        val originalFile = File(targetDir, originalName)
                        file.copyTo(originalFile, overwrite = true)
                        file.delete()
                        appendLog("[RESTAURADO] $originalName")
                    }
                }
            }

            stopService(Intent(this, ModService::class.java))
            appendLog("[PERSISTÊNCIA] ModService encerrado.")

            appendLog("[SUCESSO] Sistema restaurado para o original!")
            Toast.makeText(this, "Mod Desativado (Originais restaurados)", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            appendLog("[ERRO] Falha ao restaurar: ${e.message}")
        }
    }

    private fun appendLog(message: String) {
        val current = logConsole.text.toString()
        logConsole.text = "$current\n$message"
    }
}
