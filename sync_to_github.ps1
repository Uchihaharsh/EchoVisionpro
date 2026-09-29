# PowerShell script to quickly sync all changes to GitHub
param (
    [string]$Message = "Update Smart Glasses app"
)

Write-Host "Checking git status..." -ForegroundColor Cyan
git status -s

Write-Host "Staging all changes..." -ForegroundColor Cyan
git add .

Write-Host "Committing with message: '$Message'..." -ForegroundColor Cyan
git commit -m "$Message"

Write-Host "Pushing to GitHub (main branch)..." -ForegroundColor Cyan
git push origin main

Write-Host "Successfully synced to GitHub!" -ForegroundColor Green
