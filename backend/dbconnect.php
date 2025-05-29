<?php
$servername = "localhost";
$username   = "threenqs_alicia";
$password   = "WBd#!}ZupsH#";
$dbname     = "threenqs_iottraining_db";

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>