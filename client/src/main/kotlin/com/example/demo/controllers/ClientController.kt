package com.example.demo.controllers

import com.example.demo.models.Client
import com.example.demo.models.Letter
import javafx.application.Platform
import javafx.scene.control.Button
import javafx.scene.control.ProgressIndicator
import javafx.scene.control.TextArea
import javafx.scene.control.TextField
import kotlinx.coroutines.experimental.async
import tornadofx.*
import tornadofx.Stylesheet.Companion.button
import kotlin.concurrent.thread

class ClientController : Controller() {
    val client = Client()

    fun connect(addr : String, port : String, nick: String): Boolean {
        client.connect(addr, port)
        if (!client.authenticate(nick)) {
            return false
        }
        return true
    }

    fun run(messages: TextArea, grid : MutableList<Button>, players: TextArea, turn_progress: ProgressIndicator) {
        async {
            while(isActive) {
                while(true) {
                    var got = client.run()
                    println(got)
                    var cmd = got.split("/")
                    when (cmd[0]) {
                        "RECEPTION" -> {
                            messages.text = messages.text + cmd[1] + "\n"
                            messages.scrollTop = messages.height
                        }
                        "PRECEPTION" -> {
                            messages.text = messages.text + "[P] " + cmd[1] + "\n"
                            messages.scrollTop = Double.MAX_VALUE
                        }
                        "DECONNEXION" -> {
                            messages.text = messages.text + cmd[1] + " quit the game.\n"
                            client.send("GETPLAYERS")
                        }
                        "CONNECTE" -> {
                            messages.text = messages.text + cmd[1] + " joined the game.\n"
                            client.send("GETPLAYERS")
                        }
                        "PLAYERS" -> {
                            var players_list = cmd[1].split("|")
                            players.text = ""
                            for (player in players_list) {
                                players.text += player + "\n"
                            }
                        }
                        "TOUR" -> {
                            println("you got TOUR")
                            // Check if we have the time extension
                            if (cmd.size == 3) {
                                thread {
                                    for (i in 0..(cmd[2]).toInt() * 100) {
                                        Platform.runLater { turn_progress.progress = i.toDouble() / 100.0 }
                                        Thread.sleep(100)
                                    }
                                }
                            }
                            val gridtext = cmd[1]
                            val angles = listOf(0.0, 90.0, 180.0, 270.0)
                            Platform.runLater {
                                for (i in 0..grid.size - 1) {
                                    grid[i].text = "${gridtext[i]}"
                                    grid[i].rotate = angles.shuffled().take(1)[0]
                                    grid[i].isDisable = false
                                }
                            }
                        }
                        "RFIN" -> {
                            Platform.runLater {
                                grid.forEach { it.text = "*"; it.isDisable = true}
                                turn_progress.progress = 100.0
                            }
                        }
                    }
                }
            }
        }
        client.send("GETPLAYERS")
    }

    fun send(messages: TextArea, msg:String) {
        // Find if it's a private message
        if (msg.startsWith("/msg")) {
            val msg = msg.split(" ")
            if (msg.size < 2) { messages.text += "Error: /msg nickname message" }
            else {
                var fullmsg = ""
                for (i in 2..msg.size - 1) {
                    fullmsg += msg[i]
                }
                client.sendprivatemsg(msg[1], fullmsg)
            }
        }
        else {
            client.sendmsg(msg)
        }
    }

    fun sendword(word: MutableList<Letter>, words: TextField, grid: MutableList<Button>) {
        val wordstr = word.fold("") { acc, letter -> acc + letter.ch}
        val traj = word.fold("") { acc, letter -> acc + letter.getTrajectory()}
        client.send("TROUVE/" + wordstr + "/" + traj)
        words.clear()
        word.clear()
        grid.forEach { it.isDisable = false }
    }

    fun getgrid() {
        client.send("START/")
    }
}