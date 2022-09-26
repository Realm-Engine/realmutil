import std.stdio;
version(D_SIMD)
{
  import core.simd;
  import std.traits;
  import std.meta;
  import std.range;
  import std.algorithm;
  import std.format;
  pragma(msg,"SIMD Supported");
  struct Vector(T, int N)
  {

    public enum NumComponents = N;
            
              
              
    enum Components
    {
      x = 0,
      y = 1,
      z = 2,
      w = 3
    }


    static assert(!isAggregateType!(T),"Vector type must be of floating or integral type");
    
    alias VectorType = Alias!(__vector(T[N])); 
    private VectorType vector;

    this(T val)
    {
      vector = val;
    }

    

    this(VectorType other)
    {
      vector = other;
    }

    this(Range)(Range values) 
    in(values.length <= N)
    {
      vector = 0;
      for(int i = 0; i < values.length; i++)
      {
        vector.array[i] = values[i];

      }

    }

    @property T[N] data() const
    {
      return vector.array;
    }

    auto opBinary(string op)(T v) const 
    {
       mixin("return typeof(this)(vector" ~ op ~ "v);");
    }

    auto opBinary(string op)(typeof(this) v) const
    {
      mixin("return typeof(this)(vector" ~ op ~ "v.vector);");

    }

  

    bool opEquals( typeof(this)other) const
    {
      bool result = true;
      auto aData = data;
      auto bData = other.data;
      for(int i = 0; i < NumComponents;i++)
      {
        if(aData[i] != bData[i])
        {
          result = false;
        }
      }
      return result;
    }

    private Components getComponentIndex(string Op)()
    {
      static foreach(Component; EnumMembers!(Components))
      {
        static if(Op == __traits(identifier,EnumMembers!(Components)[Component]))
        {
          return Component;
        }
        
      }
      
    }

    @property auto opDispatch(const string Swizzle)() const if(Swizzle.length <= NumComponents && Swizzle.length > 1)
   {
     import std.conv;
      enum SwizzleSize = Swizzle.length;
      Vector!(T,NumComponents) result;
      T[SwizzleSize] arr;
      static foreach(SwizzleComponent; Swizzle)
      {
        {
          {
            
            static foreach(Component;EnumMembers!(Components))
            {
              
              static if(SwizzleComponent.to!(string) == __traits(identifier,EnumMembers!(Components)[Component]))
              {
                arr[Component] = data[Component];
              }

            }
          }
          
        }
      }
      result = Vector!(T,NumComponents)(arr);
      return result;

    }

    @property T opDispatch(const string Op)() const if(Op.length == 1)
    {
      scope(failure)
      {
        writeln("Unable to get component " ~ Op);

      }
      static foreach(Component; EnumMembers!(Components))
      {
        
        static if(Op == __traits(identifier,EnumMembers!(Components)[Component]))
        {
           
          return data[Component];

        }
      }
      
    }

  }
  public alias vec4i = Alias!(Vector!(int,4));
  public alias vec4 = Alias!(Vector!(float,4));
  unittest
  {
      
    vec4i v = vec4i(1);
    assert(!__traits(compiles,v == Vector!(int,3)(1)));
  }

  unittest
  {
    vec4i v = vec4i(1);
    vec4i v2 = vec4i(1);
    assert(v == v2);
           
  }
  unittest
  {
    vec4i v = vec4i(1) + vec4i(1);
    assert(v == vec4i(2));
    vec4 vf = vec4(1.0) + 1.0;
    assert(vf == vec4(2.0));
    assert(vf * 2.0 == vec4(4.0));
    assert(vf * vec4(2.0) == vec4(4.0));

  }

  unittest
  {
    vec4 v = vec4([0.0,1.0,2.0,3.0]);
    
    assert(v.x == 0.0);
    assert(v.y == 1.0);
    assert(v.z == 2.0);
    assert(v.w == 3.0);
    assert(v.xyz == Vector!(float,4)([0.0,1.0,2.0,0.0]));
  
  }
     
}
else
{
  pragma(msg,"SIMD not supported!");


}


