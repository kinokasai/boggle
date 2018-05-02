package com.example.demo.view

import com.example.demo.controllers.ClientController
import tornadofx.*

class LoginView : View("Login") {
    val controller : ClientController by inject()
    val address = textfield("127.0.0.1")
    val port = textfield("3434")
    val nick = textfield("kino")

    override val root = vbox {
        hbox {
            label("Address")
            this += address
        }
        hbox {
            label("Port")
            this += port
        }
        hbox {
            label("Nickname")
            this += nick
        }
        button("Connect") {
            action {
                if (!controller.connect(address.text, port.text, nick.text)) {
                    println("Could not connect")
                } else {
                    replaceWith(GameView::class)
                }
            }
        }
    }
}