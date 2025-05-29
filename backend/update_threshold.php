<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

include_once("dbconnect.php");

$id = $_POST['id'];
$temp_threshold = floatval($_POST['temp_threshold']);
$hum_threshold = floatval($_POST['hum_threshold']);


$sql = "UPDATE tbl_threshold SET temp_threshold=?, hum_threshold=? WHERE user_id=?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ddi", $temp_threshold, $hum_threshold, $id);
$stmt->execute();

if ($stmt->affected_rows > 0) {
    echo "success";
} else {
    echo "no_change";
}
?>
