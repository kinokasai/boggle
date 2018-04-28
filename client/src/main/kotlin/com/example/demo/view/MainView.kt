package com.example.demo.view

import com.example.demo.controllers.ClientController
import javafx.scene.control.Button
import javafx.scene.input.KeyCode
import tornadofx.*

class MainView : View("Hello TornadoFX") {
    val controller : ClientController by inject()
    val words = textfield()
    val grid_buttons = MutableList(16, {_ ->
        button("*") {
            style { fontFamily = "DejaVu Sans Mono"}
            action {
                words.text += text
            }
        } })

    fun get_diff(a : String, b: String): String {
        for(i in 0..b.length-1) {
            if (a[i] != b[i])
            { return "${a[i]}"}
        }
        return a.last().toString()
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
           /* words.setOnKeyTyped { event ->
                println(event.character)
                if (event.code == KeyCode.BACK_SPACE) {

                }
                val but = grid_buttons.find { button -> !button.isDisable && (button.text.toLowerCase() == event.character.toLowerCase())}
                if (but == null) {
                event.consume()
                } else {
                    but.isDisable = true
                }
            } */
            words.textProperty().addListener { obs, old, new ->
                // if we add a char, find if it's legal, remove it if not.
                if (old.length < new.length) {
                    var new_char = get_diff(new, old)
                    val but = grid_buttons.find { button -> (!button.isDisable) && button.text.toLowerCase() == new_char.toLowerCase()}
                    if (but == null) { words.text = old }
                    else { but.isDisable = true }
                } else if (old.length > new.length) { //
                    var old_char = get_diff(old, new)
                    val but = grid_buttons.find { button -> button.isDisable && button.text.toLowerCase() == old_char.toLowerCase()}
                    if (but != null) {
                        but.isDisable = false
                    }
                }
            }
            this += words
            button("Send word") {
                action {
                    grid_buttons[1].text = "A"
                }
            }
            button("get grid") {
                action {
                    controller.getgrid()
                }
            }

        }
        vbox {
            val messages = textarea {
                isEditable = false
            }
            label("Input")
            val inputField = textfield();
            button("Send") {
                action {
                    println("You sent " + inputField.text)
                    controller.send(inputField.text)
                    inputField.clear()
                }
            }
            button("Connect") {
                action {
                    println("Connecting as kino.")
                    controller.connect(messages, grid_buttons)
                }
            }
        }
    }
}