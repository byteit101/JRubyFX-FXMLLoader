=begin
 * Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
=end

#/**
# * Exposes Java Bean properties of an object via the {@link Mapend interface.
# * A call to {@link Map#get(Object)end invokes the getter for the corresponding
# * property, and a call to {@link Map#put(Object, Object)end invokes the
# * property's setter. Appending a "Property" suffix to the key returns the
# * corresponding property model.
# */
class RubyObjectWrapperBeanAdapter
  #  private final Object @bean;


  @@globalMethodCache = {}

  GET_PREFIX = "get"
  IS_PREFIX = "is"
  SET_PREFIX = "set"
  PROPERTY_SUFFIX = "Property"

  VALUE_OF_METHOD_NAME = "valueOf"

  #    static
  #        contextClassLoader = Thread.currentThread().getContextClassLoader();
  #
  #        if (contextClassLoader == nil)
  #            raise ArgumentError.new();
  #        end
  #    end

  #Creates a Bean.new adapter.
  #
  #@param @bean
  #The Bean object to wrap.
  def initialize(bean)
    @bean = bean
  end


  def getBean()
    return @bean;
  end

  def [](key)
    return @bean.send("get#{key[0].upcase}#{key[1..-1]}")
  end

  def []=(key, value)
    if (key == nil)
      raise "NULL PTR"
    end
    ty = getType(key)
    co = coerce(value, ty)
    @bean.send("set#{key[0].upcase}#{key[1..-1]}", co);
    return nil;
  end

  def read_only?(key)
    if (key == nil)
      raise "NULL PTR"
    end
    @bean.methods.include? "set#{key[0].upcase}#{key[1..-1]}"
  end

  def getType(key)
    if (key == nil)
      raise ArgumentError.new();
    end
    @bean.send(key + "GetType")
  end

  def getPropertyModel(key)
    if (key == nil)
      raise ArgumentError.new();
    end

    return @bean.send("#{key}Property")
  end

  def coerce(value, type)
    RubyWrapperBeanAdapter.coerce(value, type)
  end
end
