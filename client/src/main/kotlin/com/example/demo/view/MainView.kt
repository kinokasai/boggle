package com.example.demo.view

import com.example.demo.controllers.ClientController
import tornadofx.*

class MainView : View("Hello TornadoFX") {
    val controller : ClientController by inject()

    override val root = vbox {
        val messages = textarea() {
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
                controller.connect(messages)
            }
        }
    }
}