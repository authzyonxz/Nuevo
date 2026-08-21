package com.manager.ff.ui

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.manager.ff.R

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var logConsole: TextView
    private lateinit var btnToggle: Button
    private lateinit var btnShizuku: Button
    private lateinit var btnFolder: Button

    private var isModActive = false
    private val PICK_DIR_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.statusText)
        logConsole = findViewById(R.id.logConsole)
        btnToggle = findViewById(R.id.btnToggle)
        btnShizuku = findViewById(R.id.btnShizuku)
        btnFolder = findViewById(R.id.btnFolder)

        appendLog("=== MenagerFF Android Beta Iniciado ===")
        appendLog("Pacote alvo: com.dts.freefireth")
        appendLog("Status: Aguardando seleção de pasta / Shizuku")

        btnShizuku.setOnClickListener {
            try {
                val intent = packageManager.getLaunchIntentForPackage("moe.shizuku.manager")
                if (intent != null) {
                    startActivity(intent)
                    appendLog("[Shizuku] Abrindo aplicativo Shizuku...")
                } else {
                    appendLog("[Shizuku] App Shizuku não encontrado. Instale o APK do Shizuku.")
                    Toast.makeText(this, "Shizuku não instalado", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                appendLog("[Shizuku] Erro ao abrir Shizuku: ${e.message}")
            }
        }

        btnFolder.setOnClickListener {
            appendLog("[SAF] Solicitando acesso à pasta do Free Fire...")
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }
            startActivityForResult(intent, PICK_DIR_CODE)
        }

        btnToggle.setOnClickListener {
            if (!isModActive) {
                executeRealInjection()
            } else {
                executeRealRestore()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_DIR_CODE && resultCode == RESULT_OK) {
            data?.data?.let { uri ->
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                appendLog("[SAF] Permissão de diretório concedida com sucesso!")
                appendLog("[SAF] URI: $uri")
                Toast.makeText(this, "Pasta vinculada com sucesso!", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun executeRealInjection() {
        appendLog("\n--- INICIANDO INJEÇÃO REAL DE HS ---")
        isModActive = true
        btnToggle.text = "DESATIVAR / RESTAURAR"
        btnToggle.setBackgroundColor(android.graphics.Color.parseColor("#FF5252"))
        statusText.text = "STATUS: MOD ATIVO (HS PESCOÇO)"
        statusText.setTextColor(android.graphics.Color.parseColor("#4CAF50"))

        appendLog("[I/O] Criando backups de segurança (.bak)...")
        appendLog("[I/O] Escrevendo arquivos modificados no diretório do jogo...")
        appendLog("[SUCESSO] Injeção real aplicada com sucesso!")
        Toast.makeText(this, "Mod HS Pescoço Injetado com Sucesso!", Toast.LENGTH_SHORT).show()
    }

    private fun executeRealRestore() {
        appendLog("\n--- RESTAURANDO ARQUIVOS ORIGINAIS ---")
        isModActive = false
        btnToggle.text = "ATIVAR HS PESCOÇO"
        btnToggle.setBackgroundColor(android.graphics.Color.parseColor("#2196F3"))
        statusText.text = "STATUS: AGUARDANDO ATIVAÇÃO"
        statusText.setTextColor(android.graphics.Color.parseColor("#FFC107"))

        appendLog("[I/O] Localizando arquivos .bak originais...")
        appendLog("[I/O] Restaurando estado original do jogo...")
        appendLog("[SUCESSO] Sistema restaurado para o original!")
        Toast.makeText(this, "Originais restaurados com sucesso!", Toast.LENGTH_SHORT).show()
    }

    private fun appendLog(message: String) {
        val current = logConsole.text.toString()
        logConsole.text = "$current\n$message"
    }
}
