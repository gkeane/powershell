Add-Type -AssemblyName PresentationFramework

function Show-RebootPrompt {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')

    $form = New-Object Windows.Forms.Form
    $form.Text = 'System Reboot'
    $form.Size = New-Object Drawing.Size(300,150)
    $form.StartPosition = 'CenterScreen'

    $label = New-Object Windows.Forms.Label
    $label.Text = "Would you like to reboot now?"
    $label.AutoSize = $true
    $label.Location = New-Object Drawing.Point(75,20)
    $form.Controls.Add($label)

    $yesButton = New-Object Windows.Forms.Button
    $yesButton.Text = 'Yes'
    $yesButton.Location = New-Object Drawing.Point(50,60)
    $yesButton.Add_Click({
        Restart-Computer -Force
    })
    $form.Controls.Add($yesButton)

    $noButton = New-Object Windows.Forms.Button
    $noButton.Text = 'No'
    $noButton.Location = New-Object Drawing.Point(150,60)
    $noButton.Add_Click({
        $form.Close()
    })
    $form.Controls.Add($noButton)

    $form.Topmost = $true
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog()
}

while ($true) {
    Show-RebootPrompt
    Start-Sleep -Seconds 3600
}
