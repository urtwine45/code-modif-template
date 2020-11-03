#region fusion hashtable
Function Merge-Hashtables([ScriptBlock]$Operator) {
    $Output = @{}
    ForEach ($Hashtable in $Input) {
        If ($Hashtable -is [Hashtable]) {
            ForEach ($Key in $Hashtable.Keys) { $Output.$Key = If ($Output.ContainsKey($Key)) { @($Output.$Key) + $Hashtable.$Key } Else { $Hashtable.$Key } }
        }
    }
    If ($Operator) { ForEach ($Key in @($Output.Keys)) { $_ = @($Output.$Key); $Output.$Key = Invoke-Command $Operator } }
    $Output
}  #Permet le regroupement de l'ancien tableau avec le nouveau
#endregion fusion hashtable
#region fusion csv
Function Convert-OutputForCSV {
    <#
        .SYNOPSIS
            Provides a way to expand collections in an object property prior
            to being sent to Export-Csv.
        .DESCRIPTION
            Provides a way to expand collections in an object property prior
            to being sent to Export-Csv. This helps to avoid the object type
            from being shown such as system.object[] in a spreadsheet.
        .PARAMETER InputObject
            The object that will be sent to Export-Csv
        .PARAMETER OutPropertyType
            This determines whether the property that has the collection will be
            shown in the CSV as a comma delimmited string or as a stacked string.
            Possible values:
            Stack
            Comma
            Default value is: Stack
        .NOTES
            Name: Convert-OutputForCSV
            Author: Boe Prox
            Created: 24 Jan 2014
            Version History:
                1.1 - 02 Feb 2014
                    -Removed OutputOrder parameter as it is no longer needed; inputobject order is now respected 
                    in the output object
                1.0 - 24 Jan 2014
                    -Initial Creation
        .EXAMPLE
            $Output = 'PSComputername','IPAddress','DNSServerSearchOrder'
            Get-WMIObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'" |
            Select-Object $Output | Convert-OutputForCSV | 
            Export-Csv -NoTypeInformation -Path NIC.csv    
            
            Description
            -----------
            Using a predefined set of properties to display ($Output), data is collected from the 
            Win32_NetworkAdapterConfiguration class and then passed to the Convert-OutputForCSV
            funtion which expands any property with a collection so it can be read properly prior
            to being sent to Export-Csv. Properties that had a collection will be viewed as a stack
            in the spreadsheet.        
            
    #>
    #Requires -Version 3.0
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline)]
        [psobject]$InputObject,
        [parameter()]
        [ValidateSet('Stack', 'Comma')]
        [string]$OutputPropertyType = 'Stack'
    )
    Begin {
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose "$($_)"
        }
        $FirstRun = $True
    }
    Process {
        If ($FirstRun) {
            $OutputOrder = $InputObject.psobject.properties.name
            Write-Verbose "Output Order:`n $($OutputOrder -join ', ' )"
            $FirstRun = $False
            #Get properties to process
            $Properties = Get-Member -InputObject $InputObject -MemberType *Property
            #Get properties that hold a collection
            $Properties_Collection = @(($Properties | Where-Object {
                        $_.Definition -match "Collection|\[\]"
                    }).Name)
            #Get properties that do not hold a collection
            $Properties_NoCollection = @(($Properties | Where-Object {
                        $_.Definition -notmatch "Collection|\[\]"
                    }).Name)
            Write-Verbose "Properties Found that have collections:`n $(($Properties_Collection) -join ', ')"
            Write-Verbose "Properties Found that have no collections:`n $(($Properties_NoCollection) -join ', ')"
        }
 
        $InputObject | ForEach {
            $Line = $_
            $stringBuilder = New-Object Text.StringBuilder
            $Null = $stringBuilder.AppendLine("[pscustomobject] @{")

            $OutputOrder | ForEach {
                If ($OutputPropertyType -eq 'Stack') {
                    $Null = $stringBuilder.AppendLine("`"$($_)`" = `"$(($line.$($_) | Out-String).Trim())`"")
                }
                ElseIf ($OutputPropertyType -eq "Comma") {
                    $Null = $stringBuilder.AppendLine("`"$($_)`" = `"$($line.$($_) -join ', ')`"")                   
                }
            }
            $Null = $stringBuilder.AppendLine("}")
 
            Invoke-Expression $stringBuilder.ToString()
        }
    }
    End {}
} #Permet l'exportation en csv sans erreur 
#endregion fusion csv
if ($triggerpro.tag -ne $null) {
    $Recuptag = $triggerpro.tag | Sort-Object -unique # Récupère les tags du template
    $Tableauvlr = New-Object PSObject # Permet l'accès au métadonnées de notre tableau
    for ($numb = 0; $numb -lt $Recuptag.count; $numb++) {
        # initialise un compteur
        $tblcolumn = if ($recuptag.count -eq 1) { $Triggerpro | where tag -Contains $recuptag } 
        else { $triggerpro | where tag -Contains $recuptag[$numb] }
        if ($recuptag.count -eq 1) { $Tableauvlr | Add-Member -name $Recuptag -MemberType NoteProperty -Value $tblcolumn.value } #Supprime les doublons et initialise les tags / triggers dans $tableauvlr
        else { $Tableauvlr | Add-Member -name $Recuptag[$numb] -MemberType NoteProperty -Value $tblcolumn.value }
        if ($recuptag.count -eq 1) { $tableauvlr.($recuptag) = $tableauvlr.($recuptag) | Sort-Object -unique }
        else { $tableauvlr.($recuptag[$numb]) = $tableauvlr.($recuptag[$numb]) | Sort-Object -unique } 
        $tableauvlr | Convert-OutputForCSV  | export-csv -notype -Delimiter ";" -Path $filepath2 # extrait le tableau dans un fichier temporaire pour fusion avec l'ancien tableau
    }
}


#########################################################################################################################################
$base = Get-content $filepath | select -first 1 # recupère les tags de l'ancien tableau
$base = $base -split ";" # le split pour le réutiliser de façon plus précise
$base = $base.Replace("`"", "") # Supprime les ""
$cunt = $base.count - 1 # Recupère le nombre de tag pour le compteur 
$h1 = ipcsv $filepath -Delimiter ";" # initialise completement l'ancien tableau dans h1
$HashTable = @{} # création d'un hashtable
for ($i = 0 ; $i -le $cunt ; $i++) { # initialisation d'un compteur
    foreach ($r in $h1) { # initialise le tableau h1 dans une hashtable
        $HashTable[$base[$i]] = $r.($base[$i])
    }
    $HashTable
}
##########################################################################################################################################
$base2 = Get-content $filepath2 | select -first 1 # recupère les tags de lu nouveau tableau
if ($base2.count -ne 1) {
    # Vérifie le cas ou le tag / value serai égal à 1 ce qui pose problème la méthode doit donc être différente
    $base2 = Get-content $filepath2 | select -first 1 # recupère les tags de lu nouveau tableau
    $base2 = $base2.Replace("`"", "")  # Supprime les ""
    $cunt2 = $base2.count - 1 # Recupère le nombre de tag pour le compteur 
    $h2 = ipcsv $filepath2 -Delimiter ";" # initialise completement le nouveau tableau dans h2
    $HashTable2 = @{} # création d'un hashtable
    for ($i = 0 ; $i -le $cunt2 ; $i++) { # initialisation d'un compteur
        foreach ($r in $h2) { # initialise le tableau h2 dans une hashtable
            $HashTable2[$base2] = $r.($base2) 
        }
        $HashTable2
    }
}
else {
    $base2 = Get-content $filepath2 | select -first 1 # recupère les tags de lu nouveau tableau
    $base2 = $base2 -split ";" # Split les tags pour réutilisation
    $base2 = $base2.Replace("`"", "") # Supprime les ""
    $cunt2 = $base2.count - 1 # Recupère le nombre de tag pour le compteur 
    $h2 = ipcsv $filepath2 -Delimiter ";" # initialise completement le nouveau tableau dans h2
    $HashTable2 = @{} # création d'un hashtable
    for ($i = 0 ; $i -le $cunt2 ; $i++) { # initialisation d'un compteur
        foreach ($r in $h2) { # initialise le tableau h2 dans une hashtable
            $HashTable2[$base2[$i]] = $r.($base2[$i]) 
        }
        $HashTable2
    }
}

$csvfinal = $hashtable, $hashtable2 | Merge-Hashtables # Fusionne l'ancien et le nouveau tableau
$Output += New-Object PSObject -Property $csvfinal # Convertie notre hashtable fusionné en tableau extractable
$output | Convert-OutputForCSV  | export-csv -NoTypeInformation -Delimiter ";" -Path $filepath