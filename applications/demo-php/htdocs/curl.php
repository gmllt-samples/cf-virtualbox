<?php

function multiCurl($url, $numRequests) {
    // Create multiple cURL handles
    $multiHandle = curl_multi_init();
    $curlHandles = array();

    for ($i = 0; $i < $numRequests; $i++) {
        $curlHandles[$i] = curl_init();

        curl_setopt($curlHandles[$i], CURLOPT_URL, $url);
        curl_setopt($curlHandles[$i], CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curlHandles[$i], CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($curlHandles[$i], CURLOPT_SSL_VERIFYHOST, false);

        curl_multi_add_handle($multiHandle, $curlHandles[$i]);
    }

    curl_multi_setopt($multiHandle, CURLMOPT_MAX_TOTAL_CONNECTIONS, 10);

    // Execute all queries simultaneously, and continue when all are complete
    $running = null;
    do {
        curl_multi_exec($multiHandle, $running);
    } while ($running);

    // Close the handles
    for ($i = 0; $i < $numRequests; $i++) {
        $info = curl_getinfo($curlHandles[$i]);
        $namelookup = $info['namelookup_time_us'] / 1000;
        $connect = $info['connect_time_us'] / 1000;
        $appconnect = $info['appconnect_time_us'] / 1000;
        $pretransfer = $info['pretransfer_time_us'] / 1000;
        $starttransfer = $info['starttransfer_time_us'] / 1000;
        $total = $info['total_time_us'] / 1000;
        print('<pre>');
        echo "Request #" . ($i + 1) . ":\n";
        echo "namelookup delay: " . $namelookup . "ms \n";
        echo "connect delay: " . $connect-$namelookup . "ms \n";
        echo "appconnect delay: " . $appconnect-$connect . "ms \n";
        echo "pretransfer delay: " . $pretransfer-$appconnect . "ms \n";
        echo "starttransfer delay: " . $starttransfer-$pretransfer . "ms \n";
        echo "-------------------------\n";
        echo "total: " . $total . "ms \n\n";
        print('</pre>');

        curl_multi_remove_handle($multiHandle, $curlHandles[$i]);
        curl_close($curlHandles[$i]);
    }

    curl_multi_close($multiHandle);
}

// Check if the 'requests' query parameter is set and is a number
if (isset($_GET['requests']) && is_numeric($_GET['requests'])) {
    // Call the function with the URL and the number of requests as parameters
    multiCurl("https://demo-binary.bosh.lite.com", $_GET['requests']);
} else {
    echo "Please provide a valid number of requests as a query parameter.";
}

?>