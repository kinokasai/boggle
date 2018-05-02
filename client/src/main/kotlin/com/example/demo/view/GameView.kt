package com.example.demo.view

import com.example.demo.controllers.ClientController
import com.example.demo.models.Letter
import javafx.scene.control.Button
import javafx.scene.input.KeyCode
import tornadofx.*

class GameView : View("Hello TornadoFX") {
    fun findi(l: List<Button>, pred: (Button) -> Boolean): Pair<Button, Int>? {
        for (i in 0..l.size - 1) {
            if (pred(l[i])) {
                return Pair(l[i], i)
            }
        }
        return null
    }
    val controller : ClientController by inject()
    val word = mutableListOf<Letter>()
    var words = textfield()
    var revert = false
    var turn_progress = progressindicator { progress = 0.0 }
    val grid_buttons = MutableList(16, {_ ->
        button("*") {
            style { fontFamily = "DejaVu Sans Mono"}
            action {
                words.text += text
            }
            isDisable = true
        } })
    val chat = textarea {
        isEditable = false
        prefColumnCount = 20
    }
    val players = textarea {
        isEditable = false
        prefColumnCount = 6
    }
    fun get_diff(a : String, b: String): String {
        for(i in 0..b.length-1) {
            if (a[i] != b[i])
            { return "${a[i]}"}
        }
        return a.last().toString()
    }

    override fun onDock() {
        currentWindow?.sizeToScene()
        super.onDock()
    }
    override val root = hbox  {
        vbox {
            hbox {
                this += grid_buttons[0]
                this += grid_buttons[1]
                this += grid_buttons[2]
                this += grid_buttons[3]
            }
            hbox {
                this += grid_buttons[4]
                this += grid_buttons[5]
                this += grid_buttons[6]
                this += grid_buttons[7]
            }
            hbox {
                this += grid_buttons[8]
                this += grid_buttons[9]
                this += grid_buttons[10]
                this += grid_buttons[11]
            }
            hbox {
                this += grid_buttons[12]
                this += grid_buttons[13]
                this += grid_buttons[14]
                this += grid_buttons[15]
            }
            // FIXME: Manage the case where text is removed from the box
            words.textProperty().addListener { obs, old, new ->
                // This is absolutely disgusting, but nodody will have to maintain it, so...
                if (revert) {
                    revert = false
                    return@addListener
                }
                // if we add a char, find if it's legal, revert if not
                if (old.length < new.length) {
                    var new_char = get_diff(new, old)
                    val but = findi(grid_buttons, { (!it.isDisable) && it.text.toLowerCase() == new_char.toLowerCase()})
                    if (but == null) {
                        revert = true
                        words.text = old
                    } else {
                        word.add(Letter(but.first.text[0], but.second))
                        but.first.isDisable = true
                    }
                } else if (old.length > new.length) { //
                    var old_char = get_diff(old, new)
                    val but = grid_buttons.find { button -> button.isDisable && button.text.toLowerCase() == old_char.toLowerCase()}
                    if (but != null) {
                        but.isDisable = false
                    }
                }
            }
            words.setOnKeyPressed {
                if (it.code == KeyCode.ENTER) {
                    controller.sendword(word, words, grid_buttons)
                }
            }
            this += words
            button("Send word") {
                action {
                    controller.sendword(word, words, grid_buttons)
                }
            }
            button("get grid") {
                action {
                    controller.getgrid()
                }
            }
            this += turn_progress

        }
        vbox {
            borderpane {
                center = chat
                right = players
            }
            label("Input")
            val inputField = textfield {
                setOnKeyPressed{  event ->
                    if (event.code == KeyCode.ENTER) {
                        controller.send(chat, this.text)
                        this.clear()
                    }
                }
                prefWidth = 1.0
            }
            button("Send") {
                action {
                    println("You sent " + inputField.text)
                    controller.send(chat, inputField.text)
                    inputField.clear()
                }
            }
            controller.run(chat, grid_buttons, players, turn_progress)
        }
    }
}