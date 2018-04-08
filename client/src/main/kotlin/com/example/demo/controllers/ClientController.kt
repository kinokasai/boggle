package com.example.demo.controllers

import com.example.demo.models.Client
import javafx.scene.control.TextArea
import kotlinx.coroutines.experimental.async
import tornadofx.*

class ClientController : Controller() {
    val client = Client()

    fun connect(messages: TextArea) {
        client.connect()
        async {
            while(isActive) {
                while(true) {
                    var cmd = client.run().split("/")
                    when (cmd[0]) {
                        "RECEPTION" -> {
                            messages.text = messages.text + cmd[1] + "\n"
                        }
                        "DECONNEXION" -> {
                            messages.text = messages.text + cmd[1] + " quit the game.\n"
                        }
                        "CONNECTE" -> {
                            messages.text = messages.text + cmd[1] + " joined the game.\n"
                        }
                    }
                }
            }
        }
    }

    fun send(msg:String) {
        client.sendmsg(msg)
    }
}