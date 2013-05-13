/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package org.jruby.jfx8;

import java.util.Map;

/**
 *
 * @author patrick
 */
public abstract class RubyBeanAdapter
{
	static RubyBeanAdapter rba;
	
	public static void loadRubySpace(RubyBeanAdapter m)
	{
		rba = m;
	}

	public static Object newAndGet(Object namespace, String key)
	{
		return rba.get(namespace, key);
	}

	public static void newAndPut(Object namespace, String key, Object value)
	{
		rba.set(namespace, key, value);
	}

	public static boolean newAndContainsKey(Object namespace, String key)
	{
		return rba.contains(namespace, key);
	}
	
	
	abstract public Object get(Object namespace, String key);
	
	abstract public void set(Object namespace, String key, Object value);
	
	abstract public boolean contains(Object namespace, String key);
}
