####################################################################################
# Description du script : Job powershell qui bascule des plages DHCP du Serveur1 vers le Serveur2
#
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
# 1.0 | 23/04/2026 | MLE | Création du script
#     |            |     |
####################################################################################
function Pause-Exit {
    Read-Host "Appuyez sur Entree pour quitter le script..."
    exit
}
#$AG_NUM = [int](Read-Host "Entrez le numero de l'Agence associee a cette plage DHCP") 
#if (-not $AG_NUM) {
#    Write-Host "Pas de numero d'agence renseigne, annulation."
#    Pause-Exit
#}
#elseif (($AG_NUM -lt 100) -or ($AG_NUM -gt 199)) {
#    Write-Host "Numero d'agence non compris entre 100 et 199, annulation."
#    Pause-Exit
#}
$Failover = "{nom_bascule}"
$Vlans = @(
@{ ID = "{octet_1}.{octet_2}.{octet_3}.{octet_4}"}
@{ ID = "{octet_1}.{octet_2}.{octet_3}.{octet_4}"}
@{ ID = "{octet_1}.{octet_2}.{octet_3}.{octet_4}"}
)

foreach ($V in $Vlans) {
    if (-not (Get-DhcpServerv4Scope -ScopeID $V.ID -ErrorAction SilentlyContinue)) {
        Write-Host "Plage non existante, annulation $($V.Name)"
        Pause-Exit
    }
    else {
        Write-Host "Basculement de la plage $V.ID en cours."
        try {
            Add-DhcpServerv4FailoverScope -Name $Failover -ScopeId $V.ID -ErrorAction Stop

            Write-Host "Plage DHCP $($V.Name) basculee avec succes."
        }
        catch {
            Write-Host "Le basculement de la plage DHCP $V.ID n'a pas ete effectuee."
        }
    }
}
Pause-Exit
