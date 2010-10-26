function ConvertTo-StringData
{ 
    Begin 
    { 
       $string  = "@{`n"
        function Expand-Value
        {
            param($value)

            if ($value -ne $null) {
                switch ($value.GetType().Name)
                {
                    'String' { "`"$value`"" }
                    'Boolean' { "`$$value" }
                    default { $value }
                }
            }
            else
            { "`$null" }

        }
    } 
    Process 
    { 
        $string += $_.GetEnumerator() | foreach {"{0} = {1}`n" -f $_.Name,(Expand-Value $_.Value)}
    } 
    End 
    { 
        $string += "}" 
        Write-Output $string
    }

} #ConvertTo-StringData
