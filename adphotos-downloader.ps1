#########################################################################################
#
#                           Active Directory User Photos Downloader
# Retrieves user jpegPhotos from AD, downloads them onto a network share and deletes the
# old ones of users who no longer exist. This is designed to be run as a scheduled task
# with a SMSA account.
#
#
# Author: Hamzah Batha
# Date: 11/08/2024
# Version: 1.0
# License: MIT
# GitHub Repo: github.com/hamzah/ADphotos-downloader
#
#########################################################################################

$networkPath = "\\PATH_TO_YOUR_NETWORK_SHARE"
$mountPath = "P:"
$photoDirectory = "$mountPath/YOUR_PHOTOS_FOLDER/"
$user = "SHARE_AUTH_USERNAME"
$password = "SHARE_AUTH_PASSWORD"


$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $secPassword)

# Mount the network share
New-PSDrive -Name $mountPath[0] -PSProvider FileSystem -Root $networkPath -Credential $cred -Persist
Write-Output "Mounted network share"

# Get a list of current users with photos in AD
$activeUsers = Get-ADUser -Filter * -Properties jpegPhoto, EmailAddress | Where-Object { $_.jpegPhoto -and $_.EmailAddress } | ForEach-Object {
    [PSCustomObject]@{
        EmailAddress = $_.EmailAddress.ToLower()
        Photo = $_.jpegPhoto
    }
}

# Get a list of existing photos in the downloaded photos folder
$existingPhotos = Get-ChildItem -Path $photoDirectory -File | ForEach-Object { $_.Name.ToLower().Replace(".jpg", "") }

# Determine which photos to delete
$photosToDelete = $existingPhotos | Where-Object { $_ -notin $activeUsers.EmailAddress }

# Delete photos of users not currently in Active Directory
foreach ($photo in $photosToDelete) {
    Remove-Item -Path (Join-Path -Path $photoDirectory -ChildPath ($photo + ".jpg")) -Force
    Write-Output "Deleted photo for: $photo"
}

# Process each active user
foreach ($user in $activeUsers) {
    $photoPath = Join-Path -Path $photoDirectory -ChildPath ($user.EmailAddress + ".jpg")

    if ($existingPhotos -contains $user.EmailAddress) {
        # Update existing photo
        $user.Photo | Set-Content -Path $photoPath -Encoding Byte
        Write-Output "Updated photo for: $($user.EmailAddress)"
    } else {
        # Save new photo
        $user.Photo | Set-Content -Path $photoPath -Encoding Byte
        Write-Output "Added new photo for: $($user.EmailAddress)"
    }
}

# Unmount the network share
Remove-PSDrive -Name $mountPath[0]
Write-Output "Unmounted network share" 
