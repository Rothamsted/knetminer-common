package uk.ac.rothamsted.example;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * An Example class.
 *
 * @author brandizi
 * <dl><dt>Date:</dt><dd>19 Mar 2020</dd></dl>
 *
 */
public class ExampleClass
{
	private final String message;
	private static Logger log = LogManager.getLogger ();
	
	public ExampleClass ( String message )
	{
		this.message = message;
		log.info ( "ExampleClass initialised with '{}'", message );
	}

	public String getMessage () {
		return message;
	}
}
