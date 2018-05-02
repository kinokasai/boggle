package com.example.demo.models

import kotlinx.coroutines.experimental.async
import java.net.InetAddress
import java.net.Socket
import java.io.*;

class Client() {


    private var out: BufferedWriter?
    private var input: BufferedReader?

    init {
        out = null
        input = null
    }

    suspend fun run() : String {
        return input?.readLine()!!
    }

    fun connect(addr: String, port: String) {
        val port = port.toInt()
        var socket = Socket(addr, port)
        out = socket.getOutputStream().bufferedWriter()
        input = socket.getInputStream().bufferedReader()
    }

    fun authenticate(nick: String): Boolean {
        println("Nick:" + nick)
        val msg = "CONNEXION/" + nick + "\n"
        if (out == null) {
            return false
        }
        out!!.write(msg)
        out!!.flush()
        return true
    }

    fun sendmsg(msg: String) {
        out?.write("ENVOI/" + msg)
        out?.newLine()
        out?.flush()
    }

    fun sendprivatemsg(nick: String, msg:String) {
        out?.write("PENVOI/" + nick + "/" + msg)
        out?.newLine()
        out?.flush()
    }

    fun send(msg: String) {
        out?.write(msg)
        out?.newLine()
        out?.flush()
    }

}