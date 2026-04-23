####################################################################################
# Description du script : Job powershell qui ferme les sessions en statut autre que 'Actif'
#
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
# 1.0 | 23/04/2026 | MLE | Création du script
#     |            |     |
####################################################################################
$exclusion = @("{user_1}", "{user_2}")
$cmd = quser | Select-Object -Skip 1
foreach ($ligne in $cmd) {
    $parts = $ligne -split "\s+"
    $user = $parts[0]
    $id = $parts[2]
    $etat = $parts[3]
    if ($etat -notmatch "Actif" -and $exclusion -notcontains $user) {
        logoff $id
    }
}
