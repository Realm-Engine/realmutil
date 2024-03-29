module realmutil.rmath.linalg;

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

        private void makeVector(int i, Type, Tail...)(Type head, Tail tail)
        in (i < NumComponents)
        {

            static if (is(Type == T))
            {

                vector.array[i] = head;
                static if (i + 1 < NumComponents)
                {
                    makeVector!(i + 1)(tail);
                }
            }
            else static if (isStaticArray!(Type))
            {

                vector.array[i .. i + Type.length] = head;
                static if (i + Type.length < NumComponents)
                {
                    makeVector(i + Type.length, tail);
                }

            }

            else
            {
                static assert(false, "Cant construct vector with type " ~ Type.stringof);
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

        auto opBinary(string op)(typeof(this) v) const
        {
            mixin("return typeof(this)(vector" ~ op ~ "v.vector);");

        }

        float dot(typeof(this) other) const
        {
            auto mul = this.vector * other.vector;
            auto arr = mul.array;
            float result = 0.0f;
            for (int i = 0; i < NumComponents; i++)
            {
                result += arr[i];
            }
            return result;

        }

        static if (N == 3)
        {
            Vector!(T, N) cross(typeof(this) other) const
            {
                alias VType = Alias!(Vector!(T, N));
                Vector!(T, N) result;
                Matrix!(T, N, N) matrix = Matrix!(T, N, N)(Vector!(T,
                        N)(cast(T) 0, -this[2], this[1]), Vector!(T,
                        N)(this.z, cast(T) 0, -this[0]), Vector!(T,
                        N)(-this[1], this[0], cast(T) 0));
                auto colMatrix = cast(Matrix!(T, N, 1)) other;
                auto product = matrix * colMatrix;
                result = cast(Vector!(T, N)) product;
                return result;

            }
        }
        static if (N == 2)
        {
            float cross(typeof(this) other) const
            {
                return (this.x * other.y) - (this.y * other.x);

            }

            Vector!(T, N) orthogonal() const
            {
                return typeof(this)(this.y, -this.x);
            }
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

        ref T opIndex(int i) const
        {
            return vector.ptr[i];
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

        @property void opDispatch(const string Op)(T val) if (Op.length == 1)
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
            if (fmt.spec == 'v')
            {
                if (fmt.width > 0)
                {
                    if (fmt.width <= NumComponents)
                    {
                        for (int i = 0; i < fmt.width; i++)
                        {

                            static if (isFloatingPoint!T)
                            {

                                sink("%f ".format(data[i]));

                            }
                            else static if (isIntegral!T)
                            {
                                sink("%d".format(data[i]));
                            }
                        }
                    }
                    else
                    {
                        sink("Can not print %d components from %d component vector".format(fmt.width,
                                NumComponents));
                    }

                }
                else
                {
                    for (int i = 0; i < NumComponents; i++)
                    {

                        static if (isFloatingPoint!T)
                        {

                            sink("%f ".format(data[i]));

                        }
                        else static if (isIntegral!T)
                        {
                            sink("%d".format(data[i]));
                        }
                    }
                }
            }
            else if (fmt.flPlus)
            {
                writefln("%d", 1);
            }
        }

        public float magnitude() const
        {
            auto squared = vector * vector;
            auto v = squared.array;
            float result = 0;
            for (int i = 0; i < NumComponents; i++)
            {
                result += v[i];
            }
            return sqrt(result);
        }

        typeof(this) normalized() const
        {
            //typeof(this) result;
            float magintude = this.magnitude();
            return this * (1 / magintude);
        }

        Matrix!(T, N, 1) opCast(T : Matrix!(T, N, 1))()
        {
            return Matrix!(T, N, 1).fromVector(this);
        }

        static if (N < 4 && N > 0)
        {
            Vector!(T, N + 1) opCast(RT : Vector!(T, N + 1))()
            {
                typeof(return) result;
                for (int i = 0; i < N; i++)
                {
                    result[i] = this[i];
                }
                return result;
            }

			
        }
		static if(N <= 4 && N > 2)
		{
			Vector!(T,N - 1) opCast(RT: Vector!(T,N-1))()
			{
				typeof(return) result = makeVector!(0)(this.data[0..N-1]);
				return result;
			}
		}

    }

    public alias vec4 = Alias!(Vector!(float, 4));
    public alias vec3 = Alias!(Vector!(float, 3));
    public alias vec2 = Alias!(Vector!(float, 2));

    unittest
    {
        static assert(NextMultiple!(12, 16) == 16);
        static assert(NextMultiple!(17, 16) == 32);
    }

    unittest
    {

        assert(vec4(1.0f, 1.0f, 1.0f, 1.0f) == vec4(1.0f));
        float[4] arr = [1.0f, 1.0f, 1.0f, 1.0f];
        assert(vec4(arr) == vec4(1.0f));
        assert(vec4([1.0, 1.0, 1.0, 1.0]) == vec4(1.0));
        assert(vec4([1.0f, 2.0f, 3.0f, 4.0f]) == vec4(1.0f, 2.0f, 3.0f, 4.0f));

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
        assert(v.yxz == vec3([1.0, 0.0, 2.0]));

    }

    unittest
    {
        vec3 v1 = vec3(1.0f);
        const float expected = 1.73205;
        float actual = v1.magnitude;
        assert(isClose(actual, expected), "Expected ~ %f, got %f".format(expected, actual));
    }

    unittest
    {
        vec3 v1 = vec3(1.0f, 2.0f, 3.0f);
        vec3 v2 = vec3(4.0f, 5.0f, 6.0f);
        const float expected = 32.0f;
        float actual = v1.dot(v2);
        assert(isClose(actual, expected), "Expected ~ %f, got %f".format(expected, actual));
    }

    unittest
    {
        vec4 v1 = vec4(2.0);
        vec4 v2 = vec4(2.0);
        vec4 expected = vec4(4.0);
        vec4 actual = v1 * v2;
        assert(expected == actual, "Expected %4.v, got %4.v".format(expected, actual));
    }

    unittest
    {
        vec3 v = vec3(1.0f);
        v.x = 2.0f;
        assert(v.x == 2.0f);
    }

    unittest
    {
        vec4 v = vec4(1.0f, 2.0f, 3.0f, 4.0f);
        writefln("%3.v", v);
        writefln("%4.v", v);
        writefln("%x,y,z+v", v);
    }

    struct Matrix(T, int Rows, int Columns)
    {
        alias VectorType = Vector!(T, Columns);
        private Vector!(T, Columns)[Rows] matrix;
        public enum NumRows = Rows;
        public enum NumColumns = Columns;
        private void makeMatrix(int x, int y, Type, Tail...)(Type head, Tail tail)
        {
            static if (is(Type == Vector!(T, Columns)))
            {
                matrix[y] = head;
                static if (y + 1 < Rows)
                {
                    makeMatrix!(x, y + 1)(tail);
                }

            }
            else static if (isStaticArray!(Type))
            {

            }

        }

        @property T[NumColumns][NumRows] data()
        {
            typeof(return) result;
            for (int r = 0; r < NumRows; r++)
            {
                result[r] = matrix[r].data.array;
            }
            return result;
        }

        this(Args...)(Args args)
        {
            makeMatrix!(0, 0)(args);
        }

        this(T val)
        {
            for (int i = 0; i < Rows; i++)
            {
                matrix[i] = VectorType(val);
            }

        }

        static typeof(this) identity()
        {
            typeof(this) matrix = typeof(this)(0);
            static if (__traits(isFloating, T))
            {
                for (int i = 0; i < NumRows; i++)
                {
                    matrix[i, i] = 1.0f;
                }
            }
            else static if (__traits(isIntegral, T))
            {
                for (int i = 0; i < NumRows; i++)
                {
                    matrix[i, i] = 1;
                }
            }
            return matrix;

        }

        @property auto ref opDispatch(const string Op)() if (Op.length == 1)
        {
            static foreach (Component; EnumMembers!(ComponentNames))
            {

                static if (Op == __traits(identifier, EnumMembers!(ComponentNames)[Component]))
                {

                    return matrix[Component];

                }
            }
        }

        auto opBinary(string op, ST)(ST scalar)
                if (op == "*" && __traits(isScalar, ST))
        {
            typeof(this) product;
            for (int r = 0; r < NumRows; r++)
            {
                auto rP = this[r] * scalar;
                product[r] = rP;
            }
            return product;
        }

        private Matrix!(T, NumRows, 1) matrixColMatrixProduct(MT)(MT colMatrix)
                if (MT.NumColumns == 1 && MT.NumRows == NumColumns)
        {
            //Matrix!(T,1,NumColumns) rowMatrix = colMatrix.transposed;
            Vector!(T, NumColumns) rowMatrix;
            int r, c;
            for (r = 0; r < MT.NumRows; r++)
            {
                rowMatrix[r] = colMatrix[r, 0];
            }

            Matrix!(T, NumRows, 1) result;
            for (r = 0; r < NumRows; r++)
            {
                auto row = this[r];
                float d = row.dot(rowMatrix);

                result[r, 0] = d;

            }
            return result;

        }

        Matrix!(T, NumRows, MT.NumColumns) opBinary(string op, MT)(MT other)
                if (op == "*" && !__traits(isScalar, MT) && NumColumns == MT.NumRows)
        {

            Matrix!(T, NumRows, MT.NumColumns) product;

            static if (MT.NumColumns == 1)
            {
                product = matrixColMatrixProduct(other);
            }
            else
            {
                auto bT = other.transposed;
                for (int r = 0; r < NumRows; r++)
                {

                    for (int c = 0; c < MT.NumColumns; c++)
                    {
                        auto rP = this[r] * bT[c];
                        float sum = 0;

                        for (int i = 0; i < NumColumns; i++)
                        {
                            sum += rP[i];
                        }
                        product[r, c] = sum;
                    }

                }
            }

            return product;
        }

        ref T opIndex(int i, int j)
        {
            return matrix[i][j];
        }

        ref Vector!(T, NumColumns) opIndex(int i)
        {
            return matrix[i];
        }

        auto transposed()
        {
            Matrix!(T, NumColumns, NumRows) result;
            for (int x = 0; x < NumColumns; x++)
            {
                for (int y = 0; y < NumRows; y++)
                {
                    result[x, y] = data[y][x];
                }
            }
            return result;
        }

        void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
        {
            if (fmt.spec == 'm')
            {
                if (fmt.width > 0)
                {
                    if (fmt.width <= NumRows)
                    {
                        for (int i = 0; i < fmt.width; i++)
                        {

                            static if (isFloatingPoint!T)
                            {

                                sink("%v\n".format(matrix[i]));

                            }
                            else static if (isIntegral!T)
                            {
                                sink("%v\n".format(matrix[i]));
                            }
                        }
                    }
                    else
                    {
                        sink("Can not print %d rows from %d component rows".format(fmt.width,
                                NumRows));
                    }

                }
            }
            else if (fmt.flPlus)
            {
                writefln("%d", 1);
            }
        }

        static Matrix!(T, M, 1) fromVector(T, int M)(Vector!(T, M) vector)
        {
            Matrix!(T, M, 1) result;
            int i, j;
            for (i = 0; i < M; i++)
            {
                result[i][0] = vector[i];
            }
            return result;
        }

        Vector!(T, NumRows) opCast(RT : Vector!(T, NumRows))() if (NumColumns == 1)
        {
            Vector!(T, NumRows) result;
            for (int r = 0; r < NumRows; r++)
            {

                result[r] = this[r, 0];
            }
            return result;
        }

        Vector!(T, NumRows) opCast(RT : Vector!(T, NumRows))() if (NumRows == 1)
        {
            Vector!(T, NumRows) result;
            for (int r = 0; r < NumColumns; r++)
            {
                result[r] = this[0, r];
            }
            return result;
        }

    }

    alias mat4 = Alias!(Matrix!(float, 4, 4));
    alias mat2 = Alias!(Matrix!(float, 2, 2));
    alias ColumnMatrix(int M) = Alias!(Matrix!(float, M, 1));
    unittest
    {
        mat4 mat = mat4(vec4(1.0), vec4(1.0), vec4(1.0), vec4(1.0));
        assert(mat.x == vec4(1.0f));
        assert(mat.y == vec4(1.0f));
        assert(mat.z == vec4(1.0f));
        assert(mat.w == vec4(1.0f));
        mat = mat4(1.0f);
        assert(mat.x == vec4(1.0f));
        mat.x.x = 2.0f;
        assert(mat.x.x == 2.0f);

    }

    unittest
    {
        mat4 mat1 = mat4(1.0f);
        mat4 mat2 = mat4(2.0f);
        mat4 result = mat1 * mat2;
        writeln("%4.m".format(result));

    }

    unittest
    {
        Matrix!(float, 3, 3) matrix1 = Matrix!(float, 3, 3)(vec3(1.0f, 2.0f,
                1.0f), vec3(0.0f, 1.0f, 0.0f), vec3(2.0f, 3.0f, 4.0f));
        Matrix!(float, 3, 2) matrix2 = Matrix!(float, 3, 2)(vec2(2.0f, 5.0f),
                vec2(6.0f, 7.0f), vec2(1.0f, 8.0f));
        Matrix!(float, 3, 2) result = matrix1 * matrix2;
        writeln("A:\n%3.m".format(matrix1));
        writeln("B:\n%2.m".format(matrix2.transposed));
        writeln("%3.m".format(result));
    }

    unittest
    {
        mat2 mat = mat2(vec2(1.0f, 2.0f), vec2(3.0f, 4.0f));
        mat2 transpos = mat.transposed();
        mat2 expected = mat2(vec2(1.0f, 3.0f), vec2(2.0f, 4.0f));

        assert(transpos == expected, "Expected: \n%2.m, got: \n%2.m".format(expected, transpos));

    }

    unittest
    {
        Matrix!(float, 3, 2) matrix = Matrix!(float, 3, 2)(vec2(1.0f, 2.0f),
                vec2(3.0f, 4.0f), vec2(5.0f, 6.0f));
        Matrix!(float, 2, 3) transposed = matrix.transposed();
        Matrix!(float, 2, 3) expected = Matrix!(float, 2, 3)(vec3(1.0f, 3.0f,
                5.0f), vec3(2.0f, 4.0f, 6.0f));
        assert(transposed == expected,
                "Expected: \n%2.m, got: \n %2.m".format(expected, transposed));
    }

    unittest
    {
        mat4 matrix = mat4.identity();
        matrix = matrix * 5.0f;

        writeln("%4.m".format(matrix));
    }

    unittest
    {
        vec4 vec = vec4(1.0f);
        ColumnMatrix!(4) mat = ColumnMatrix!(4).fromVector(vec);
        writeln("%4.m".format(mat));
    }

    unittest
    {
        Matrix!(float, 2, 3) mat = Matrix!(float, 2, 3)(vec3(1.0f, -1.0f,
                2.0f), vec3(0.0f, -3.0f, 1.0f));
        vec3 vec = vec3(2.0f, 1.0f, 0.0f);
        ColumnMatrix!(3) colMat = cast(ColumnMatrix!(3)) vec;
        auto product = mat * colMat;
        writeln("%2.m".format(product));
    }

    unittest
    {
        vec3 v1 = vec3(1.0f, 0.0f, 0.0f);
        vec3 v2 = vec3(0.0f, 0.0f, 1.0f);
        vec3 result = v1.cross(v2);
        writefln("%3.v", result);
        assert(result == vec3(0.0f, -1.0f, 0.0f));
    }

    unittest
    {
        ColumnMatrix!(3) cM = ColumnMatrix!(3)().fromVector(vec3(1.0f, 1.0f, 1.0f));

        vec3 v = cast(vec3) cM;
        writefln("%3.v", v);
    }

    unittest
    {
        vec2 v1 = vec2(0.7f, 0.1f);
        vec2 v2 = vec2(0.0f, 1.0f);
        writefln("%f", v1.cross(v2));
        writefln("%2.v", v1.orthogonal);
    }

    struct Quaternion(QT)
	{
		static assert(__traits(isFloating,QT),"Quaternion types must be floating point");
        public Vector!(QT,3) vector;
		public QT scalar;

		


		this(Args...)(Args args)
		{
			makeQuaternion!0(args);
		}
		private void makeQuaternion(int i, Type, Tail...)(Type head, Tail tail)
		{
			static if(i < 3)
			{
				static if(is(Type==QT))
				{
					vector.makeVector!(i)(head,tail);
					static if(i+1 < 4)
					{
						makeQuaternion!(i+1)(tail);
					}

				}
				static if(is(Type == Vector!(QT,3)))
				{
					vector = head;
					makeQuaternion!(i + 3)(tail);
				}

			}
			else 
			{
				static if(is(Type==QT))
				{
					scalar = head;
				}
				
			}
		}
		@property auto opDispatch(const string Swizzle)() const 
                if (Swizzle.length > 1)
        {
			return vector.opDispatch!(Swizzle)();
		}


		void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
        {
			if(fmt.spec == 'q')
			{
				sink("%3.v %f".format(vector,scalar));
			}
			
		}

		auto opBinary(string op)(typeof(this) other) const if(op == "*") 
		{

			Vector!(QT,3) vectorPart = vector.cross(other.vector) + (vector * scalar) + ( other.vector * other.scalar);
			QT scalarPart = (other.scalar * this.scalar) - this.vector.dot(other.vector);
			typeof(this) result = typeof(this)(vectorPart,scalarPart);
			return result; 
		}



	}

	alias quat = Alias!(Quaternion!(float));

	unittest
	{
		quat q = quat(2.0f,0.0f,0.0f,1.0f);
		quat q2 = quat(1.0f,0.0f,1.0f,1.0f);
		quat product = q * q2;
		writefln("%q",product);


	}

}
else
{
    pragma(msg, "SIMD not supported!");

}
