####################################################################################
# Description du script : Job powershell qui supprime une/des plage.s DHCP suivant un numéro d'agence
#                         Et retire la relation de basculement s'il en existe une.
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
# 1.0 | 23/0/2026 | MLE | Création du script
#     |            |     |
####################################################################################
function Pause-Exit {
    Read-Host "`nAppuyez sur Entree pour quitter le script..."
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
$Failover = "{nom_bascule}"

$Vlans = @(
@{ ID = "192.$AG_NUM.0.0"}
@{ ID = "192.$AG_NUM.10.0"}
)

foreach ($V in $Vlans) {
    $CheckScope = Get-DhcpServerv4Scope -ScopeId $($V.ID) -ErrorAction SilentlyContinue
    if ($null -eq $CheckScope) {
        Write-Host "La plage $($V.ID) n'existe pas."
        Pause-Exit
    }
    Remove-DhcpServerv4FailoverScope -Name $Failover -ScopeId $($V.ID) -Force -ErrorAction Stop
    Remove-DhcpServerv4Scope -ScopeId $($V.ID) -Force
    Write-Host "Plage $($V.ID) supprimee."
}
Pause-Exit
