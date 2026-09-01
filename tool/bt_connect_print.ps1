Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(-1) | Out-Null
  $netTask.Result
}

[Windows.Devices.Bluetooth.BluetoothDevice, Windows.Devices.Bluetooth, ContentType = WindowsRuntime] | Out-Null
[Windows.Devices.Bluetooth.Rfcomm.RfcommDeviceService, Windows.Devices.Bluetooth.Rfcomm, ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.Sockets.StreamSocket, Windows.Networking.Sockets, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataWriter, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null

$mac = [uint64]0x28D41E64A41D
$device = Await ([Windows.Devices.Bluetooth.BluetoothDevice]::FromBluetoothAddressAsync($mac)) ([Windows.Devices.Bluetooth.BluetoothDevice])
Write-Output "Before: $($device.Name) status=$($device.ConnectionStatus)"

$services = Await ([Windows.Devices.Bluetooth.Rfcomm.RfcommDeviceService]::GetServicesForDeviceAsync($device)) ([Windows.Devices.Enumeration.DeviceInformationCollection])
Write-Output "RFCOMM services: $($services.Count)"
foreach ($svc in $services) {
  Write-Output "  service id=$($svc.Id)"
}

$sppId = [Windows.Devices.Bluetooth.Rfcomm.RfcommServiceId]::SerialPort
$serviceResult = Await ([Windows.Devices.Bluetooth.Rfcomm.RfcommDeviceService]::FromIdAsync($sppId.AsString())) ([Windows.Devices.Bluetooth.Rfcomm.RfcommDeviceService])
# above might not work - need FromBluetoothAddressAsync

$service = Await ([Windows.Devices.Bluetooth.Rfcomm.RfcommDeviceService]::FromBluetoothAddressAsync($mac, $sppId)) ([Windows.Devices.Bluetooth.Rfcomm.RfcommDeviceService])
Write-Output "SPP service connection=$($service.ConnectionStatus)"

$socket = New-Object Windows.Networking.Sockets.StreamSocket
Await ($socket.ConnectAsync($service.ConnectionHostName, $service.ConnectionServiceName)) ([Void])
Write-Output "Socket connected"

$writer = New-Object Windows.Storage.Streams.DataWriter($socket.OutputStream)
$bytes = [byte[]](0x1B,0x40) + [System.Text.Encoding]::ASCII.GetBytes("BT CONNECTED TEST`n") + [byte[]](0x1B,0x64,0x03)
[void]$writer.WriteBytes($bytes)
Await ($writer.StoreAsync()) ([UInt32])
Await ($writer.FlushAsync()) ([Boolean])
Write-Output "Print bytes sent via RFCOMM socket"
Start-Sleep -Seconds 1
$socket.Dispose()
Write-Output "After: status=$($device.ConnectionStatus)"
