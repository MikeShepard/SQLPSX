function ConvertFrom-Xml($XML) {
    foreach ($Object in @($XML.Objects.Object)) {
        $PSObject = New-Object PSObject
        foreach ($Property in @($Object.Property)) {
            $PSObject | Add-Member NoteProperty -Name $Property.Name -Value $Property.InnerText
        }
        $PSObject
    }
}

