####################################################################################
# Description du script : Job powershell qui créé une/des plage.s DHCP suivant un nom/numéro d'agence
#
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
# 1.0 | 23/0/2026 | MLE | Création du script
#     |            |     |
####################################################################################
function Pause-Exit {
    Read-Host "Appuyez sur Entree pour quitter le script..."
    exit
}
$AG_NUM = [int](Read-Host "Entrez le numero de l'Agence associee a cette plage DHCP") 
if (-not $AG_NUM) {
    Write-Host "Pas de numero d'agence renseigne, annulation."
    Pause-Exit
}
elseif (($AG_NUM -lt 100) -or ($AG_NUM -gt 199)) {
    Write-Host "Numero d'agence non compris entre 100 et 199, annulation."
    Pause-Exit
}

$AG_NOM = Read-Host "Entrez le nom de l'Agence associee a cette plage DHCP"
if (-not $AG_NOM) {
    Write-Host "Pas de nom d'agence renseigne, annulation."
    Pause-Exit
}
$Vlans = @(
@{ ID = "192.$AG_NUM.0.0"; Name = "VLAN{vlan}_$AG_NOM"; Start = "192.$AG_NUM.0.1"; End = "192.$AG_NUM.0.5"; G = "192.$AG_NUM.0.254"; 
   M = "255.255.255.0"; NTP = "192.168.0.254"; D = "{description}"; B = "08.00:00:00"}
)

foreach ($V in $Vlans) {
    if (-not (Get-DhcpServerv4Scope -ScopeID $V.ID -ErrorAction SilentlyContinue)) {
        Write-Host "Creation de la plage DHCP $($V.Name)"
        Add-DhcpServerv4Scope -Name $V.Name -StartRange $V.Start -EndRange $V.End -SubnetMask $V.M -Description $V.D -LeaseDuration $V.B -ErrorAction Stop
        try {
            Set-DhcpServerv4OptionValue -ScopeID $V.ID -Router $V.G -ErrorAction Stop
            if ($V.NTP) { Set-DhcpServerv4OptionValue -ScopeID $V.ID -OptionId 4  -Value $V.NTP }
            Write-Host "Plage DHCP $($V.Name) configuree avec succes."
        }
        catch {
            Write-Host "La configuration de la plage DHCP $V.Name n'a pas ete effectuee."
        }
    }
    else {
        Write-Host "La plage $($V.ID) ($($V.Name)) existe deja, elle est donc ignoree."
    }
}
