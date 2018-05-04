package com.example.demo.controllers

import com.example.demo.models.Client
import com.example.demo.models.Letter
import javafx.application.Platform
import javafx.scene.control.Button
import javafx.scene.control.ProgressIndicator
import javafx.scene.control.TextArea
import javafx.scene.control.TextField
import javafx.scene.media.Media
import javafx.scene.media.MediaPlayer
import javafx.util.Duration
import kotlinx.coroutines.experimental.async
import tornadofx.*
import tornadofx.Stylesheet.Companion.button
import kotlin.concurrent.thread
import javafx.animation.KeyFrame
import javafx.animation.KeyValue
import javafx.animation.Timeline



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
            val think_track = MediaPlayer(Media("file:/home/kino/Projects/boggle/client/rsc/antiquity.wav"))
            val stress_track = MediaPlayer(Media("file:/home/kino/Projects/boggle/client/rsc/seismic.wav"))
            val timeline = Timeline(
            KeyFrame(Duration.seconds(2.0),
                    KeyValue(think_track.volumeProperty(), 0),
                    KeyValue(stress_track.volumeProperty(), 100)))
            stress_track.startTime = Duration(15000.0)
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
                            if (cmd.size > 2) {
                                messages.text = messages.text + cmd[2] + " is now known as " + cmd[1] + "\n"
                            }
                            else {
                                messages.text = messages.text + cmd[1] + " joined the game.\n"
                            }
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
                            think_track.volume = 100.0
                            stress_track.volume = 0.0
                            stress_track.play()
                            // Check if we have the time extension
                            if (cmd.size == 3) {
                                thread {
                                    for (i in 0..100) {
                                        Platform.runLater { turn_progress.progress = i.toDouble() / 100 }
                                        Thread.sleep(cmd[2].toLong() * 10)
                                    }
                                }
                                thread {
                                    think_track.play()
                                }
                                thread {
                                    Thread.sleep(cmd[2].toLong() * 1000 - 10000)

                                    timeline.play()
                                    timeline.setOnFinished {
                                        //stress_track.play()
                                        think_track.stop()
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
                            stress_track.stop()
                            Platform.runLater {
                                grid.forEach { it.text = "*"; it.isDisable = true}
                                turn_progress.progress = 100.0
                            }
                        }
                        "VAINQUEUR" -> {
                            Platform.runLater {
                                messages.text += "Game finished!\nScores:\n"
                                cmd[1].split("|").forEach {
                                    if (it != "") {
                                        val tmp = it.split("*")
                                        messages.text = messages.text + tmp[0] + ": " + tmp[1] + "\n"
                                    }
                                }
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