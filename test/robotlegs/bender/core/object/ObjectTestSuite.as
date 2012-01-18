//------------------------------------------------------------------------------
//  Copyright (c) 2011 the original author or authors. All Rights Reserved. 
// 
//  NOTICE: You are permitted to use, modify, and distribute this file 
//  in accordance with the terms of the license agreement accompanying it. 
//------------------------------------------------------------------------------

package robotlegs.bender.core.object
{
	import robotlegs.bender.core.object.processor.impl.ObjectProcessorTest;
	import robotlegs.bender.core.object.processor.impl.TypeCachedObjectProcessorTest;

	[RunWith("org.flexunit.runners.Suite")]
	[Suite]
	public class ObjectTestSuite
	{

		/*============================================================================*/
		/* Public Properties                                                          */
		/*============================================================================*/

		public var objectProcessor:ObjectProcessorTest;

		public var typeCachedObjectProcessor:TypeCachedObjectProcessorTest;
	}
}
