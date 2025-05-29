<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include_once("dbconnect.php");
$user_id = $_GET['id'];
$sql = "SELECT temp_threshold, hum_threshold FROM tbl_threshold WHERE user_id = '$user_id'";
$result = $conn->query($sql);
if ($row = $result->fetch_assoc()) {
    echo json_encode($row);
} else {
    echo json_encode(["temp_threshold" => 35.0, "hum_threshold" => 80.0]);
}
?>
