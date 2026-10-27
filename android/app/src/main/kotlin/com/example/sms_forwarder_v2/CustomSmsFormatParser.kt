package com.example.sms_forwarder_v2

data class CustomMatchResult(
    val amount: Double? = null,
    val trxId: String? = null,
    val sender: String? = null,
    val balance: Double? = null,
    val fee: Double? = null,
    val account: String? = null,
    val currency: String? = null,
    val date: String? = null,
    val isMatched: Boolean = false,
)

object CustomSmsFormatParser {

    data class CompiledTemplate(
        val regex: Regex,
        val groupMap: Map<String, Int>,
    )

    fun compileTemplate(template: String): CompiledTemplate? {
        val clean = template.trim()
        if (clean.isEmpty()) return null

        val groupMap = mutableMapOf<String, Int>()
        var groupIndex = 1

        val placeholderRegex = Regex("""\{([A-Za-z0-9_]+|\.\.\.)\}""")
        val patternBuffer = StringBuilder()
        var lastEnd = 0

        for (match in placeholderRegex.findAll(clean)) {
            val literalBefore = clean.substring(lastEnd, match.range.first)
            if (literalBefore.isNotEmpty()) {
                patternBuffer.append(escapeLiteral(literalBefore))
            }

            val tag = match.groupValues.getOrNull(1)?.lowercase() ?: ""
            when (tag) {
                "amount", "amt" -> {
                    patternBuffer.append("""([0-9,]+(?:\.[0-9]{1,2})?)""")
                    groupMap["amount"] = groupIndex++
                }
                "trxid", "txnid", "ref", "reference" -> {
                    patternBuffer.append("""([A-Za-z0-9_-]+)""")
                    groupMap["trxId"] = groupIndex++
                }
                "sender", "from", "recipient", "counterparty" -> {
                    patternBuffer.append("""([^\n,.]+)""")
                    groupMap["sender"] = groupIndex++
                }
                "balance", "bal" -> {
                    patternBuffer.append("""([0-9,]+(?:\.[0-9]{1,2})?)""")
                    groupMap["balance"] = groupIndex++
                }
                "fee", "charge" -> {
                    patternBuffer.append("""([0-9,]+(?:\.[0-9]{1,2})?)""")
                    groupMap["fee"] = groupIndex++
                }
                "account", "ac", "card" -> {
                    patternBuffer.append("""([A-Za-z0-9*_-]+)""")
                    groupMap["account"] = groupIndex++
                }
                "currency" -> {
                    patternBuffer.append("""([A-Za-z$€£৳₹]+)""")
                    groupMap["currency"] = groupIndex++
                }
                "date", "datetime", "time" -> {
                    patternBuffer.append("""([0-9A-Za-z/:\s,-]+)""")
                    groupMap["date"] = groupIndex++
                }
                "any", "..." -> {
                    patternBuffer.append("""(?:.*?)""")
                }
                else -> {
                    patternBuffer.append("""(?:.*?)""")
                }
            }
            lastEnd = match.range.last + 1
        }

        if (lastEnd < clean.length) {
            val literalAfter = clean.substring(lastEnd)
            patternBuffer.append(escapeLiteral(literalAfter))
        }

        return try {
            val compiled = Regex(patternBuffer.toString(), RegexOption.IGNORE_CASE)
            CompiledTemplate(compiled, groupMap)
        } catch (_: Exception) {
            null
        }
    }

    private fun escapeLiteral(literal: String): String {
        val escaped = literal.replace(Regex("""[\\^$.|?*+(){}\[\]]""")) { "\\${it.value}" }
        return escaped.replace(Regex("""\s+"""), """\s+""")
    }

    fun parse(template: String, body: String): CustomMatchResult {
        val compiled = compileTemplate(template) ?: return CustomMatchResult()
        val match = compiled.regex.find(body) ?: return CustomMatchResult()

        val amtStr = compiled.groupMap["amount"]?.let { match.groupValues.getOrNull(it) }
        val amount = amtStr?.replace(",", "")?.toDoubleOrNull()

        val trxId = compiled.groupMap["trxId"]?.let { match.groupValues.getOrNull(it)?.trim()?.uppercase() }
        val sender = compiled.groupMap["sender"]?.let { match.groupValues.getOrNull(it)?.trim() }
        val balStr = compiled.groupMap["balance"]?.let { match.groupValues.getOrNull(it) }
        val balance = balStr?.replace(",", "")?.toDoubleOrNull()
        val feeStr = compiled.groupMap["fee"]?.let { match.groupValues.getOrNull(it) }
        val fee = feeStr?.replace(",", "")?.toDoubleOrNull()
        val account = compiled.groupMap["account"]?.let { match.groupValues.getOrNull(it)?.trim() }
        val currency = compiled.groupMap["currency"]?.let { match.groupValues.getOrNull(it)?.trim() }
        val date = compiled.groupMap["date"]?.let { match.groupValues.getOrNull(it)?.trim() }

        return CustomMatchResult(
            amount = amount,
            trxId = trxId,
            sender = sender,
            balance = balance,
            fee = fee,
            account = account,
            currency = currency,
            date = date,
            isMatched = true,
        )
    }

    fun matches(template: String, body: String): Boolean {
        val compiled = compileTemplate(template) ?: return false
        return compiled.regex.containsMatchIn(body)
    }
}
