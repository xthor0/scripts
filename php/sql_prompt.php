<?PHP

define( 'DB_HOST',     'devshanghai.datamark-inc.com' );
define( 'DB_DATABASE', 'Stingray' );
define( 'DB_USER',     'Stingray' );
define( 'DB_PASS',     'stingray' );

function doLog( $line = "\n" ){
	print $line."\n";
	error_log( $line."\n", 3, 'sql.log' );
}

$con = new PDO(
	(
		PHP_OS == 'WINNT'
		? 'odbc:Driver={SQL Server};Server='.DB_HOST.';Database='.DB_DATABASE
		: 'dblib:host='.DB_HOST.';dbname='.DB_DATABASE
	),
	DB_USER,
	DB_PASS
);

while( ( $sql = trim( readline( 'SQL: ' ) ) ) != 'x' ){
	if( empty( $sql ) ){ continue; }
	print 'Executing SQL: '.$sql."\n\n";
	doLog( $sql );
	$stmt = false;
	try {
		$stmt = $con->query( $sql );
		if( is_object( $stmt ) ){
			doLog( var_export( $stmt->fetchAll( PDO::FETCH_ASSOC ), true ) );
		} else {
			doLog( var_export( $con->errorInfo(), true ) );
		}
	} catch( Exception $e ){
		doLog( $e->getMessage() );
	}
	doLog();
}
