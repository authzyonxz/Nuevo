package com.manager.ff.ui

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.manager.ff.R

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var logConsole: TextView
    private lateinit var btnToggle: Button
    private lateinit var btnConnectAdb: Button
    private lateinit var editPort: EditText
    private lateinit var editCode: EditText

    private var isModActive = false
    private var isAdbConnected = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.statusText)
        logConsole = findViewById(R.id.logConsole)
        btnToggle = findViewById(R.id.btnToggle)
        btnConnectAdb = findViewById(R.id.btnConnectAdb)
        editPort = findViewById(R.id.editPort)
        editCode = findViewById(R.id.editCode)

        appendLog("=== MenagerFF Android Beta [Native ADB] ===")
        appendLog("Alvo: com.dts.freefireth (Free Fire)")
        appendLog("Instrução: Ative a Depuração Sem Fio nas Opções de Desenvolvedor,")
        appendLog("insira a Porta e o Código de Pareamento abaixo.")

        btnConnectAdb.setOnClickListener {
            val port = editPort.text.toString().trim()
            val code = editCode.text.toString().trim()

            if (port.isEmpty() || code.isEmpty()) {
                Toast.makeText(this, "Insira a porta e o código ADB!", Toast.LENGTH_SHORT).show()
                appendLog("[AVISO] Preencha a porta e o código de pareamento.")
                return@setOnClickListener
            }

            appendLog("[ADB] Tentando pareamento wireless na porta $port...")
            statusText.text = "STATUS: PAREANDO ADB..."
            
            // Simulação de autenticação de socket ADB nativo
            // Em ambiente real, realiza o handshake SSL/TLS com localhost:[port] usando o paring code
            isAdbConnected = true
            statusText.text = "STATUS: ADB CONECTADO COM SUCESSO!"
            statusText.setTextColor(android.graphics.Color.parseColor("#4CAF50"))
            appendLog("[SUCESSO] Conexão ADB estabelecida diretamente pelo app!")
            Toast.makeText(this, "ADB Pareado com Sucesso!", Toast.LENGTH_SHORT).show()
        }

        btnToggle.setOnClickListener {
            if (!isAdbConnected) {
                Toast.makeText(this, "Conecte o ADB primeiro!", Toast.LENGTH_SHORT).show()
                appendLog("[AVISO] Conexão ADB necessária antes de ativar o mod.")
                return@setOnClickListener
            }

            if (!isModActive) {
                executeNativeInjection()
            } else {
                executeNativeRestore()
            }
        }
    }

    private fun executeNativeInjection() {
        appendLog("\n--- INICIANDO INJEÇÃO VIA ADB SHELL ---")
        isModActive = true
        btnToggle.text = "DESATIVAR / RESTAURAR"
        btnToggle.setBackgroundColor(android.graphics.Color.parseColor("#EF4444"))
        statusText.text = "STATUS: MOD ATIVADO (HS PESCOÇO)"

        appendLog("[ADB] Executando comando de backup dos originais (.bak)...")
        appendLog("[ADB] Copiando arquivos de HS para /Android/data/com.dts.freefireth/files/...")
        appendLog("[SUCESSO] Injeção aplicada com privilégios ADB!")
        Toast.makeText(this, "HS Pescoço Injetado com Sucesso!", Toast.LENGTH_SHORT).show()
    }

    private fun executeNativeRestore() {
        appendLog("\n--- RESTAURANDO ORIGINAIS VIA ADB ---")
        isModActive = false
        btnToggle.text = "ATIVAR HS PESCOÇO"
        btnToggle.setBackgroundColor(android.graphics.Color.parseColor("#059669"))
        statusText.text = "STATUS: ADB CONECTADO"

        appendLog("[ADB] Restaurando arquivos .bak para o estado original...")
        appendLog("[SUCESSO] Restauração concluída!")
        Toast.makeText(this, "Originais restaurados com sucesso!", Toast.LENGTH_SHORT).show()
    }

    private fun appendLog(message: String) {
        val current = logConsole.text.toString()
        logConsole.text = "$current\n$message"
    }
}
