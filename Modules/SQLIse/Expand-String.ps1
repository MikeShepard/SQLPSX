
    param([String]$text)

        $returnedText = ""
        foreach ( $line in $text -split [System.Environment]::NewLine ) {
            if ( $line.length -gt 0) {
                if ($line -match '(\$(\w+))')
                #{ $line = $line -replace '(\$(\w+))',(get-variable $matches[2] -Scope Global -ValueOnly) }
                { $line = $line -replace '(\$(\w+))',(get-variable $matches[2] -ValueOnly) }
            }
            $returnedText += "{0}{1}" -f $line, [System.Environment]::NewLine
        }
        $returnedText
