<?php 
[
'mysql' => [
    'driver' => 'mysql',
    'url' => env('DATABASE_URL'),
    'host' => env('DB_HOST', '127.0.0.1'),
    'port' => env('DB_PORT', '3306'),
    'database' => env('DB_DATABASE', 'forge'),
    'username' => env('DB_USERNAME', 'forge'),
    'password' => env('DB_PASSWORD', ''),
    'unix_socket' => env('DB_SOCKET', ''),
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'prefix' => '',
    'prefix_indexes' => true,
    'strict' => false,
    'engine' => null,
    'ssl_mode' => env('SSL_MODE'),
    'options' => [
        PDO::ATTR_PERSISTENT => false,  // disable to reuse same connection        
        PDO::ATTR_EMULATE_PREPARES => true, // disable proxysql prepared statement caching // specially discovered for eoffice only
    ],
],
];
