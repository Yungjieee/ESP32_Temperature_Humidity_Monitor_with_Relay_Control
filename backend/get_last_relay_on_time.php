<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");


include_once("dbconnect.php"); // Include your database connection

// Query to get the last timestamp when the relay status was "ON"
$query = "SELECT date FROM tbl_dht_training WHERE relay_status = 'ON' ORDER BY date DESC LIMIT 1";
$result = $conn->query($query);

// Check if the query returned a result
if ($result->num_rows > 0) {
    // If result found, fetch the data
    $row = $result->fetch_assoc();
    echo json_encode(['last_relay_on_time' => $row['date']]);
} else {
    // If no "ON" status found, return a message
    echo json_encode(['last_relay_on_time' => 'No ON status found']);
}
?>
