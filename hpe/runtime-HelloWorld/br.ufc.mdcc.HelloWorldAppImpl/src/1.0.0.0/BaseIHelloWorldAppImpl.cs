/* Automatically Generated Code */

using System;
using br.ufc.pargo.hpe.backend.DGAC;
using br.ufc.pargo.hpe.basic;
using br.ufc.pargo.hpe.kinds;
using br.ufc.mdcc.HelloWorld;
using br.ufc.mdcc.HelloWorldApp;

namespace br.ufc.mdcc.HelloWorldAppImpl { 

public abstract class BaseIHelloWorldAppImpl: Application, BaseIHelloWorldApp
{

private IHelloWorld helloworld = null;

protected IHelloWorld Helloworld {
	get {
		if (this.helloworld == null)
			this.helloworld = (IHelloWorld) Services.getPort("helloworld");
		return this.helloworld;
	}
}



}

}
