<?php
include_once("dbconnect.php");
$sql = "SELECT * FROM tbl_dht_training ORDER BY id DESC LIMIT 1";
$result = $conn->query($sql);
$row = $result->fetch_assoc();

$status = "Normal";
if ($row['temp'] > 26 || $row['hum'] > 70) {
    $status = "Alert";
}
echo json_encode([
  "temp" => $row['temp'],
  "hum" => $row['hum'],
  "status" => $status
]);
?>
