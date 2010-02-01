include stdlib, stdio, ctype, stdint, stdbool, string

/**
 * objects
 */
Object: abstract class {

    class: Class
        
    /// Instance initializer: set default values for a new instance of this class
    __defaults__: func {}
    
    /// Finalizer: cleans up any objects belonging to this instance
    __destroy__: func {}
    
    instanceOf: final func (T: Class) -> Bool {
        class inheritsFrom(T)
    }

    /*
    toString: func -> String {
        "%s@%p" format(class name, this)
    }
    */
    
}

Class: abstract class {
    
    /// Number of octets to allocate for a new instance of this class 
    instanceSize: SizeT
    
    /// Number of octets to allocate to hold an instance of this class
    /// it's different because for classes, instanceSize may greatly
    /// vary, but size will always be equal to the size of a Pointer.
    /// for basic types (e.g. Int, Char, Pointer), size == instanceSize
    size: SizeT

    /// Human readable representation of the name of this class
    name: String
    
    /// Pointer to instance of super-class
    super: const Class
    
    /// Create a new instance of the object of type defined by this class
    alloc: final func -> Object {
        object := gc_malloc(instanceSize) as Object
        if(object) {
            object class = this
            object __defaults__()
        }
        return object
    }
    
    inheritsFrom: final func (T: Class) -> Bool {
        if(this == T) return true
        return (super ? super inheritsFrom(T) : false)
    }
    
}

None: class {init: func {}}


/**
 * Pointer type
 */
Void: cover from void
Pointer: cover from void* {
    toString: func -> String { "%p" format(this) }
}

/**
 * character and pointer types
 */
Char: cover from char {
    // check for an alphanumeric character
    isAlphaNumeric: func -> Bool {
        isAlpha() || isDigit()
    }

    // check for an alphabetic character
    isAlpha: func -> Bool {
        isLower() || isUpper()
    }

    // check for a lowercase alphabetic character
    isLower: func -> Bool {
        this >= 'a' && this <= 'z'
    }

    // check for an uppercase alphabetic character
    isUpper: func -> Bool {
        this >= 'A' && this <= 'Z'
    }

    // check for a decimal digit (0 through 9)
    isDigit: func -> Bool {
        this >= '0' && this <= '9'
    }

    // check for a hexadecimal digit (0 1 2 3 4 5 6 7 8 9 a b c d e f A B C D E F)
    isHexDigit: func -> Bool {
        isDigit() ||
        (this >= 'A' && this <= 'F') ||
        (this >= 'a' && this <= 'f')
    }

    // check for a control character
    isControl: func -> Bool {
        (this >= 0 && this <= 31) || this == 127
    }

    // check for any printable character except space
    isGraph: func -> Bool {
        isPrintable() && this != ' '
    }

    // check for any printable character including space
    isPrintable: func -> Bool {
        this >= 32 && this <= 126
    }

    // check for any printable character which is not a space or an alphanumeric character
    isPunctuation: func -> Bool {
        isPrintable() && !isAlphaNumeric() && this != ' '
    }

    // check for white-space characters: space, form-feed ('\f'), newline ('\n'),
    // carriage return ('\r'), horizontal tab ('\t'), and vertical tab ('\v')
    isWhitespace: func -> Bool {
        this == ' '  ||
        this == '\n' ||
        this == '\r' ||
        this == '\t' ||
        this == '\f' ||
        this == '\v'
    }

    // check for a blank character; that is, a space or a tab
    isBlank: func -> Bool {
        this == ' ' || this == '\t'
    }

    toInt: func -> Int {
        if (isDigit()) {
            return (this - '0')
        }
        return -1
    }

    toLower: extern(tolower) func -> This

    toUpper: extern(toupper) func -> This

    print: func {
        printf("%c", this)
    }

    println: func {
        printf("%c\n", this)
    }
}

SChar: cover from signed char extends Char
UChar: cover from unsigned char extends Char
WChar: cover from wchar_t

//String: cover from Char*
String: cover from char* {
    
    toInt:    extern(atoi)  func -> Int
    toLong:   extern(atol)  func -> Long
    toLLong:  extern(atoll) func -> LLong
    toDouble: extern(atof)  func -> Double
    toFloat:  extern(atof)  func -> Float
    
    first: func -> SizeT {
        return this[0]
    }
    
    lastIndex: func -> SizeT {
        return length() - 1
    }
    
    last: func -> Char {
        return this[lastIndex()]
    }
    
    println: func {
        printf("%s\n", this)
    }
    
    length: extern(strlen) func -> SizeT
    
    append: func(other: This) -> This {
        length := length()
        rlength := other length()
        copy := gc_malloc(length + rlength + 1) as Char*
        memcpy(copy, this, length)
        memcpy(copy as Char* + length, other, rlength + 1) // copy the final '\0'
        return copy
    }
    
    prepend: func (other: This) -> This {
        other append(this)
    }
    
    format: func (...) -> String {
        list:VaList

        va_start(list, this)
        
        // TODO: use String new() instead (when rock supports constructors with suffixes properly)
        length := vsnprintf(null, 0, this, list) + 1
        output: String = gc_malloc(length)
        va_end(list)

        va_start(list, this)
        vsnprintf(output, length, this, list)
        va_end(list)

        return output
    }
    
}

operator + (left, right: String) -> String {
    return left append(right)
}

/*
operator + (left: LLong, right: String) -> String {
    left toString() + right
}

operator + (left: String, right: LLong) -> String {
    left + right toString()
}

operator + (left: Int, right: String) -> String {
    left toString() + right
}

operator + (left: String, right: Int) -> String {
    left + right toString()
}

operator + (left: Bool, right: String) -> String {
    left toString() + right
}

operator + (left: String, right: Bool) -> String {
    left + right toString()
}

operator + (left: Double, right: String) -> String {
    left toString() + right
}

operator + (left: String, right: Double) -> String {
    left + right toString()
}

operator + (left: String, right: Char) -> String {
    left append(right)
}

operator + (left: Char, right: String) -> String {
    right prepend(left)
}
*/

LLong: cover from signed long long {
    
    toString:    func -> String { "%lld" format(this) }
    toHexString: func -> String { "%llx" format(this) }
    
    isOdd:  func -> Bool { this % 2 == 1 }
    isEven: func -> Bool { this % 2 == 0 }
    
    in: func(range: Range) -> Bool {
        return this >= range min && this < range max
    }
    
}
    
Long:  cover from signed long  extends LLong
Short: cover from signed short extends LLong
Int:   cover from signed int   extends LLong

ULLong: cover from unsigned long long extends LLong {

    toString:    func -> String { "%llu" format(this) }
    
    in: func(range: Range) -> Bool {
        return this >= range min && this < range max
    }
    
}

ULong:  cover from unsigned long  extends ULLong
UInt:   cover from unsigned int   extends ULLong
UShort: cover from unsigned short extends ULLong


/**
 * fixed-size integer types
 */
Int8:   cover from int8_t extends LLong
Int16:  cover from int16_t extends LLong
Int32:  cover from int32_t extends LLong
Int64:  cover from int64_t extends LLong

UInt8:  cover from uint8_t extends ULLong
UInt16: cover from uint16_t extends ULLong
UInt32: cover from uint32_t extends ULLong
UInt64: cover from uint64_t extends ULLong

//Octet: cover from UInt8
Octet:  cover from uint8_t
SizeT:  cover from size_t extends LLong
Bool:   cover from bool {
    toString: func -> String { this ? "true" : "false" }
}

/**
 * real types
 */
LDouble: cover from long double
Double: cover from double extends LDouble
Float: cover from float extends LDouble

/**
 * custom types
 */
Range: cover {

    min, max: Int
    
    new: static func (.min, .max) -> This {
        this : This
        this min = min
        this max = max
        return this
    }

}

/**
 * iterators
 */
/*
Iterator: abstract class <T> {

    hasNext: abstract func -> Bool
    next: abstract func -> T
    
    hasPrev: abstract func -> Bool
    prev: abstract func -> T
    
    remove: abstract func -> Bool
    
}

Iterable: abstract class <T> {

    iterator: abstract func -> Iterator<T>*/

    /**
     * @return the contents of the iterable as ArrayList.
     */
    /*
    toArrayList: func -> ArrayList<T> {
        result := ArrayList<T> new()
        for(elem: T in this) {
            result add(elem)
        }
        result
    }
    */
/*}*/


/**
 * exceptions
 */
Exception: class {

    origin: Class
    msg : String

    init: func ~originMsg (=origin, =msg) {}
    init: func ~noOrigin (=msg) {}
    
    crash: func {
        //FIXME: add global variables support for rock!
        //fflush(stdout)
        x := 0
        x = 1 / x
    }
    
    getMessage: func -> String {
        //max := const 1024
        max : const Int = 1024
        buffer := gc_malloc(max) as String
        if(origin) snprintf(buffer, max, "[%s in %s]: %s\n", this as Object class name, origin name, msg)
        else snprintf(buffer, max, "[%s]: %s\n", this as Object class name, msg)
        return buffer
    }
    
    print: func {
        //FIXME: add global variable support for rock!
        //fprintf(stderr, "%s", getMessage())
        printf("%s", getMessage())
    }
    
    throw: func {
        print()
        crash()
    }

}
