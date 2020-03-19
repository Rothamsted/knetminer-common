package uk.ac.rothamsted.example;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.junit.Assert;
import org.junit.Test;


/**
 * Sample Unit Test
 *
 * @author brandizi
 * <dl><dt>Date:</dt><dd>19 Mar 2020</dd></dl>
 *
 */
public class ExampleClassTest
{
	private static Logger log = LogManager.getLogger ();
	
	@Test
	public void testExample ()
	{
		log.debug ( "Running --- testExample ---" );
		String hello = "Hello, World!";
		ExampleClass testObj = new ExampleClass ( hello );
		Assert.assertEquals ( "Wrong message!", hello, testObj.getMessage () );
		log.trace ( "End --- testExample ---" );
	}
}
