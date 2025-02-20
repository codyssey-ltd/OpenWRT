<?php
/*
curl -i -X POST -H "Content-Type: multipart/form-data" -H 'Authorization: eyJhbGciOiJIUzI1NiIsInR5cCI6ImFjY2Vzcy' -F "Host=test10-owrt" -F "wgconf=@/tmp/test10-owrt-wg0.enc" https://wg01.asm.co.il:58249/
*/
header("Content-Type: text/plain");
$headers = getallheaders();
//print_r($headers);

if ((!array_key_exists('Authorization-Token', $headers)) || ($headers["Authorization-Token"] !== 'eyJhbGciOiJIUzI1NiIsInR5cCI6ImFjY2Vzcy')) {
   echo json_encode(["error" => "Authorization header is missing"]);
   header("HTTP/1.1 403 OK");
   exit;
}

$target_dir = "/opt/wireguard-configurator/encrypted/";

if (isset($_FILES['wgconf'])) {
   $errors = array();
   $file_name = $_FILES['wgconf']['name'];
   $file_size = $_FILES['wgconf']['size'];
   $file_tmp = $_FILES['wgconf']['tmp_name'];
   $file_type = $_FILES['wgconf']['type'];
   $file_ext = strtolower(end(explode('.', $_FILES['wgconf']['name'])));

   $extensions = array("enc");

   if (in_array($file_ext, $extensions) === false) {
      $errors[] = "extension not allowed, please choose a valid file." . PHP_EOL;
      header("HTTP/1.1 403 OK");
   }

   if ($file_size > 10240) {
      header("HTTP/1.1 413 OK");
      $errors[] = 'File size exceedes the limit';
   }

   if (empty($errors) == true) {
      move_uploaded_file($file_tmp, $target_dir . $file_name);
      echo "Success";
   } else {
      header("HTTP/1.1 500 OK");
      json_encode($errors);
   }
}
?>