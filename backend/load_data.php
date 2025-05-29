<?php

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include_once("dbconnect.php");
$result = $conn->query("SELECT * FROM tbl_dht_training ORDER BY id");

$data = array();
while ($row = $result->fetch_assoc()) {
$data[] = [
  "id" => (int)$row['id'],
  "temp" => (float)$row['temp'],
  "hum" => (float)$row['hum'],
  "timestamp" => $row['date'],
  "relay_status" => $row['relay_status']
  ];
}
echo json_encode($data);
?>
