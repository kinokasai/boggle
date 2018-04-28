package com.example.demo.models

import kotlinx.coroutines.experimental.async
import java.net.InetAddress
import java.net.Socket
import java.io.*;

class Client() {


    private var out: BufferedWriter
    private var input: BufferedReader

    init {
        var socket = Socket("127.0.0.1", 3434)
        out = socket.getOutputStream().bufferedWriter()
        input = socket.getInputStream().bufferedReader()
    }

    suspend fun run() : String {
        return input.readLine()
    }

    fun connect() {
        val msg = "CONNEXION/kino\n"
        out.write(msg)
        out.flush()
    }

    fun sendmsg(msg: String) {
        out.write("ENVOI/" + msg)
        out.newLine()
        out.flush()
    }

    fun send(msg: String) {
        out.write(msg)
        out.newLine()
        out.flush()
    }

}