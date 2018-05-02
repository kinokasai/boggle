package com.example.demo.models

data class Letter(val ch: Char, val index: Int) {
    fun getTrajectory(): String {
        val letters = listOf("A", "B", "C", "D")
        val numbers = listOf("1", "2", "3", "4")
        return letters[index/4] + numbers[index%4]
    }
}
