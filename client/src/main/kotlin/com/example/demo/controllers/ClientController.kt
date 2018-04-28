package com.example.demo.controllers

import com.example.demo.models.Client
import javafx.application.Platform
import javafx.scene.control.Button
import javafx.scene.control.TextArea
import kotlinx.coroutines.experimental.async
import tornadofx.*
import tornadofx.Stylesheet.Companion.button

class ClientController : Controller() {
    val client = Client()

    fun connect(messages: TextArea, grid : MutableList<Button>) {
        client.connect()
        async {
            while(isActive) {
                while(true) {
                    var got = client.run()
                    println(got)
                    var cmd = got.split("/")
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
                        "TOUR" -> {
                            println("you got TOUR")
                            val gridtext = cmd[1]
                            Platform.runLater {
                                for (i in 0..grid.size - 1) {
                                    grid[i].text = "${gridtext[i]}"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    fun send(msg:String) {
        client.sendmsg(msg)
    }

    fun getgrid() {
        client.send("gimme")
    }
}