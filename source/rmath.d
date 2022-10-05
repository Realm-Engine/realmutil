import std.stdio;

version (D_SIMD)
{
	import core.simd;
	import std.traits;
	import std.meta;
	import std.range;
	import std.algorithm;
	import std.format;
	import std.math.operations;
	import std.math.algebraic;
	pragma(msg, "SIMD Supported");

	enum bool IsSupportedVectorType(T, int n) = (is(T[n] == void[16])
				|| is(T[n] == byte[16]) || is(T[n] == ubyte[16])
				|| is(T[n] == short[8]) || is(T[n] == ushort[8])
				|| is(T[n] == int[4]) || is(T[n] == uint[4])
				|| is(T[n] == long[2]) || is(T[n] == ulong[2])
				|| is(T[n] == float[4]) || is(T[n] == double[2])
				|| is(T[n] == void[32]) || is(T[n] == byte[32])
				|| is(T[n] == ubyte[32]) || is(T[n] == short[16])
				|| is(T[n] == ushort[16]) || is(T[n] == int[8])
				|| is(T[n] == uint[8]) || is(T[n] == long[4])
				|| is(T[n] == ulong[4]) || is(T[n] == float[8]) || is(T[n] == double[8]));

	enum NextMultiple(int N, int Multiple) = N + (Multiple - N % Multiple);
	enum ComponentNames
	{
		x = 0,
		y = 1,
		z = 2,
		w = 3
	}
	struct Vector(T, int N)
	{
		public enum NumComponents = N;

		static if (!IsSupportedVectorType!(T, N))
		{
			enum VectorSize = NextMultiple!(T.sizeof * N, 16) / T.sizeof;

			alias VectorType = Alias!(__vector(T[VectorSize]));
		}
		else
		{
			enum VectorSize = N;
			alias VectorType = Alias!(__vector(T[VectorSize]));
		}

		

		static assert(!isAggregateType!(T), "Vector type must be of floating or integral type");
		private VectorType vector;

		this(T val)
		{
			vector = val;
		}

		this(VectorType other)
		{
			vector = other;
		}

		private void makeVector(int i,Type, Tail...)(Type head, Tail tail)
		in(i < NumComponents)
		{
			
			static if(is(Type == T))
			{
				
				vector.array[i] = head;
				static if(i + 1 < NumComponents)
				{
					makeVector!(i+1)(tail);
				}
			}
			else static if(isStaticArray!(Type))
			{
				
				vector.array[i..i+Type.length] = head;
				static if(i + Type.length < NumComponents)
				{
					makeVector(i + Type.length,tail);
				}
				
			}
			
			else
			{
				static assert(false,"Cant construct vector with type " ~ Type.stringof);
			}

			   
		}

		

		this(Args...)(Args args)
		{
			makeVector!(0)(args);
		
		}

		@property T[NumComponents] data() const
		{
			return vector.array[0 .. NumComponents];
		}

		

		auto opBinary(string op)(T v) const
		{
			mixin("return typeof(this)(vector" ~ op ~ "v);");
		}

		auto opBinary(string op)(typeof(this) v) const if(op != "*")
		{
			mixin("return typeof(this)(vector" ~ op ~ "v.vector);");

		}

		float opBinary(string op)(typeof(this)other) const if(op == "*")
		{
			auto mul = this.vector * other.vector;
			auto arr = mul.array;
			float result = 0.0f;
			for(int i = 0; i < NumComponents;i++)
			{
				result += arr[i];
			}
			return result;

		}

		bool opEquals(typeof(this) other) const
		{
			bool result = true;
			auto aData = data;
			auto bData = other.data;
			for (int i = 0; i < NumComponents; i++)
			{
				if (aData[i] != bData[i])
				{
					result = false;
				}
			}
			return result;
		}

		@property auto opDispatch(const string Swizzle)() const 
				if (Swizzle.length <= NumComponents && Swizzle.length > 1)
		{
			import std.conv;

			enum SwizzleSize = Swizzle.length;
			Vector!(T, SwizzleSize) result;
			T[SwizzleSize] arr;
			int swizzleIndex = 0;
			static foreach (SwizzleComponent; Swizzle)
			{

				static foreach (Component; EnumMembers!(ComponentNames))
				{

					static if (SwizzleComponent.to!(string) == __traits(identifier,
							EnumMembers!(ComponentNames)[Component]))
					{
						arr[swizzleIndex] = data[Component];
					}

				}
				swizzleIndex++;
			}
			result = Vector!(T, SwizzleSize)(arr);
			return result;

		}

		@property T opDispatch(const string Op)() const if (Op.length == 1)
		{
			static foreach (Component; EnumMembers!(ComponentNames))
			{

				static if (Op == __traits(identifier, EnumMembers!(ComponentNames)[Component]))
				{

					return data[Component];

				}
			}

		}

		@property void opDispatch(const string Op)(T val) if(Op.length == 1)
		{
			static foreach (Component; EnumMembers!(ComponentNames))
			{

				static if (Op == __traits(identifier, EnumMembers!(ComponentNames)[Component]))
				{

					vector.ptr[Component] = val;

				}
			}
		}

    void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
    {
      
      

      if(fmt.spec == 'v')
      {
        if(fmt.width > 0)
        {
          if(fmt.width <= NumComponents)
          {
            for(int i = 0; i < fmt.width;i++)
            {

              static if(isFloatingPoint!T)
              {
                
                sink("%f ".format(data[i]));

              }
              else static if(isIntegral!T)
              {
                sink("%d".format(data[i]));
              }
            }
          }
          else
          {
            sink("Can not print %d components from %d component vector".format(fmt.width,NumComponents));
          }
         
        }
      }
      else if(fmt.flPlus)
      {
        writefln("%d",1);
      }
    }

		public float magnitude()
		{
			auto squared = vector * vector;
			auto v = squared.array;
			float result = 0;
			for(int i = 0; i < NumComponents;i++)
			{
				result += v[i];
			}
			return sqrt(result);


		}

		

	}

	
	public alias vec4 = Alias!(Vector!(float, 4));
	public alias vec3 = Alias!(Vector!(float,3));
	unittest
	{
		static assert(NextMultiple!(12, 16) == 16);
		static assert(NextMultiple!(17, 16) == 32);
	}

	unittest
	{
		
		assert(vec4(1.0f,1.0f,1.0f,1.0f) == vec4(1.0f));
		float[4] arr = [1.0f,1.0f,1.0f,1.0f];
		assert(vec4(arr) == vec4(1.0f));
		assert(vec4([1.0,1.0,1.0,1.0]) == vec4(1.0));
		assert(vec4([1.0f,2.0f,3.0f,4.0f]) == vec4(1.0f,2.0f,3.0f,4.0f));
		
	}

	unittest
	{
		vec4 v = vec4(1.0);
		vec4 v2 = vec4(1.0);
		assert(v == v2);

	}

	unittest
	{
		vec4 v = vec4(1.0) + vec4(1.0);
		assert(v == vec4(2.0));
		vec4 vf = vec4(1.0) + 1.0;
		assert(vf == vec4(2.0));
		assert(vf * 2.0 == vec4(4.0));
		

	}

	unittest
	{
		vec4 v = vec4([0.0, 1.0, 2.0, 3.0]);

		assert(v.x == 0.0);
		assert(v.y == 1.0);
		assert(v.z == 2.0);
		assert(v.w == 3.0);
		assert(v.xyz == vec3([0.0, 1.0, 2.0]));
		assert(v.yxz == vec3([1.0,0.0,2.0]));

	}

	unittest
	{
		vec3 v1 = vec3(1.0f);
		const float expected = 1.73205;
		float actual = v1.magnitude;
		assert(isClose(actual,expected),"Expected ~ %f, got %f".format(expected,actual));
	}
	unittest
	{
		vec3 v1 = vec3(1.0f,2.0f,3.0f);
		vec3 v2 = vec3(4.0f,5.0f,6.0f);
		const float expected = 32.0f;
		float actual = v1 * v2;
		assert(isClose(actual,expected),"Expected ~ %f, got %f".format(expected,actual));
	}

	unittest
	{
		vec3 v = vec3(1.0f);
		v.x = 2.0f;
		assert(v.x == 2.0f);
	}
  unittest
  {
    vec4 v = vec4(1.0f,2.0f,3.0f,4.0f);
    writefln("%3.v",v);
    writefln("%4.v",v);
    writefln("%x,y,z+v",v);
  }

	struct Matrix(T,int Rows, int Columns)
	{
		alias VectorType = Vector!(T,Columns);
		private Vector!(T,Columns)[Rows] matrix;
		
		private void makeMatrix(int x,int y, Type, Tail...)(Type head, Tail tail)
		{
			static if(is(Type == Vector!(T,Columns)))
			{
				matrix[y] = head;
        static if(y + 1 < Rows)
        {
          	makeMatrix!(x,y + 1)(tail); 
        }
			
			}
			else static if(isStaticArray!(Type))
			{
				
			}

		}


		this(Args...)(Args args)
		{
			makeMatrix!(0,0)(args);
		}
		this(T val)
		{
			for(int i = 0; i < Rows;i++)
			{
				matrix[i] = VectorType(val);
			}
		
		}

		@property auto ref opDispatch(const string Op)() if(Op.length == 1)
		{
			static foreach (Component; EnumMembers!(ComponentNames))
			{

				static if (Op == __traits(identifier, EnumMembers!(ComponentNames)[Component]))
				{

					return matrix[Component];

				}
			}
		}

		

	}
	alias mat4 = Alias!(Matrix!(float,4,4));
	unittest
	{
		mat4 mat = mat4(vec4(1.0),vec4(1.0),vec4(1.0),vec4(1.0));
		assert(mat.x == vec4(1.0f));
    assert(mat.y == vec4(1.0f));
    assert(mat.z == vec4(1.0f));
    assert(mat.w == vec4(1.0f));
		mat = mat4(1.0f);
		assert(mat.x == vec4(1.0f));
		mat.x.x = 2.0f;
		assert(mat.x.x == 2.0f);

	}

}
else
{
	pragma(msg, "SIMD not supported!");

}
