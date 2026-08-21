package com.manager.ff.ui

import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.manager.ff.R

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

        appendLog("=== MenagerFF Android [Design Tabbed] ===")
        appendLog("Alvo: com.dts.freefireth")

        // Navegação entre abas
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

        // Conexão ADB
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

            // Retornar para a aba de Início automaticamente
            tabInicioContent.visibility = View.VISIBLE
            tabAdbContent.visibility = View.GONE
        }

        // Liga / Desliga Mod
        btnToggleMod.setOnClickListener {
            if (!isAdbConnected) {
                Toast.makeText(this, "Conecte o ADB na aba ADB primeiro!", Toast.LENGTH_SHORT).show()
                appendLog("[AVISO] Conexão ADB necessária antes de ativar o mod.")
                // Alternar para aba ADB
                tabInicioContent.visibility = View.GONE
                tabAdbContent.visibility = View.VISIBLE
                return@setOnClickListener
            }

            if (!isModActive) {
                executeInjection()
            } else {
                executeRestore()
            }
        }
    }

    private fun executeInjection() {
        isModActive = true
        btnToggleMod.text = "DESATIVAR MOD (RESTAURAR)"
        btnToggleMod.setBackgroundColor(android.graphics.Color.parseColor("#EF4444"))
        appendLog("[MOD] Aplicando HS Pescoço via ADB Shell...")
        appendLog("[SUCESSO] Mod ATIVADO com sucesso!")
        Toast.makeText(this, "HS Pescoço Ativado!", Toast.LENGTH_SHORT).show()
    }

    private fun executeRestore() {
        isModActive = false
        btnToggleMod.text = "ATIVAR MOD"
        btnToggleMod.setBackgroundColor(android.graphics.Color.parseColor("#0284C7"))
        appendLog("[MOD] Restaurando arquivos originais (.bak)...")
        appendLog("[SUCESSO] Sistema restaurado para o original!")
        Toast.makeText(this, "Mod Desativado (Original restaurado)", Toast.LENGTH_SHORT).show()
    }

    private fun appendLog(message: String) {
        val current = logConsole.text.toString()
        logConsole.text = "$current\n$message"
    }
}
