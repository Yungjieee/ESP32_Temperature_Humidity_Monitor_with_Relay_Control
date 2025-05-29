<?php
error_reporting(0);
include_once("dbconnect.php");

$id = $_GET['id'];
$temp = $_GET['temp'];
$hum = $_GET['hum'];
$relay = $_GET['relay'];

$sqlinsert = "INSERT INTO `tbl_dht_training`(`user_id`, `temp`, `hum`, `relay_status`) VALUES ('$id','$temp','$hum', '$relay')";

if ($conn->query($sqlinsert) === TRUE){
    echo "success";
}else{
    echo "failed";
}

?>