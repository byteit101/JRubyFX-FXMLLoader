# * Copyright (c) 2013 Patrick Plenefisch
# * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
# *
# * This code is free software; you can redistribute it and/or modify it
# * under the terms of the GNU General Public License version 2 only, as
# * published by the Free Software Foundation.  Oracle designates this
# * particular file as subject to the "Classpath" exception as provided
# * by Oracle in the LICENSE file that accompanied this code.
# *
# * This code is distributed in the hope that it will be useful, but WITHOUT
# * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# * version 2 for more details (a copy is included in the LICENSE file that
# * accompanied this code).
# *
# * You should have received a copy of the GNU General Public License version
# * 2 along with this work; if not, write to the Free Software Foundation,
# * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
# *

require 'digest/sha1'

def javafx
  Java::javafx
end

class FxmlJitInfo
  include JRubyFX
  def self.hash(file)
    Digest::SHA1.hexdigest file
  end
  # TODO: store jit settings in here instead of $RB_* variables
  attr_accessor :file_name, :raw_code, :jit_settings
  def initialize(file_name, jit_settings=1, opts = nil)
    @file_name = file_name
    @jit_settings = jit_settings
    @run_count = 0
    @opts = opts
  end
  def hash
    FxmlJitInfo.hash(@file_name)
  end
  def should_jit?
    return false if @jit_settings == :no_jit || compiled?
    return true if (@run_count += 1) >= @jit_settings
  end
  def compiled?
    @jitted == true
  end
  def decompile
    @jitted = false
  end
  def compile(code=@raw_code)
    @raw_code = code
    # TODO: begin rescue end
    full_code =  <<METHOD_DEF
    def __build_via_jit(__local_fxml_controller, __local_namespace)
      __local_fx_id_setter = lambda do |name, __i|
        __local_namespace[name] = __i
        __local_fxml_controller.instance_variable_set(("@\#{name}").to_sym, __i)
      end
#{code}
    end
METHOD_DEF
    ;#)
    if @opts && @opts[:compile_hook]
      @opts[:compile_hook].call(full_code)
    end
    self.instance_eval full_code
    @jitted = true
  end
  Infinity = 1.0/0.0
end
