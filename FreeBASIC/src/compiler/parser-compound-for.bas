''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.


'' FOR..NEXT compound statement parsing
''
'' chng: sep/2004 written [v1ctor]

option explicit
option escape

#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\parser.bi"
#include once "inc\ast.bi"

'':::::
private function cStoreTemp( byval expr as ASTNODE ptr, _
							 byval dtype as integer ) as FBSYMBOL ptr static
    dim as FBSYMBOL ptr s
    dim as ASTNODE ptr vexpr

	function = NULL

	s = symbAddTempVar( dtype )
	if( s = NULL ) then
		exit function
	end if

	vexpr = astNewVAR( s, 0, dtype )
	astAdd( astNewASSIGN( vexpr, expr ) )

	function = s

end function

'':::::
private sub cFlushBOP( byval op as integer, _
					   byval dtype as integer, _
	 		   		   byval v1 as FBSYMBOL ptr, _
	 		   		   byval val1 as FBVALUE ptr, _
			   		   byval v2 as FBSYMBOL ptr, _
			   		   byval val2 as FBVALUE ptr, _
			   		   byval ex as FBSYMBOL ptr ) static

	dim as ASTNODE ptr expr1, expr2, expr

	'' bop
	if( v1 <> NULL ) then
		expr1 = astNewVAR( v1, 0, dtype )
	else
		select case as const dtype
		case IR_DATATYPE_LONGINT, IR_DATATYPE_ULONGINT
			expr1 = astNewCONST64( val1->long, dtype )
		case IR_DATATYPE_SINGLE, IR_DATATYPE_DOUBLE
			expr1 = astNewCONSTf( val1->float, dtype )
		case else
			expr1 = astNewCONSTi( val1->int, dtype )
		end select
	end if

	if( v2 <> NULL ) then
		expr2 = astNewVAR( v2, 0, dtype )
	else
		select case as const dtype
		case IR_DATATYPE_LONGINT, IR_DATATYPE_ULONGINT
			expr2 = astNewCONST64( val2->long, dtype )
		case IR_DATATYPE_SINGLE, IR_DATATYPE_DOUBLE
			expr2 = astNewCONSTf( val2->float, dtype )
		case else
			expr2 = astNewCONSTi( val2->int, dtype )
		end select
	end if

	expr = astNewBOP( op, expr1, expr2, ex, FALSE )

	''
	astAdd( expr )

end sub

'':::::
private sub cFlushSelfBOP( byval op as integer, _
						   byval dtype as integer, _
	 		       		   byval v1 as FBSYMBOL PTR, _
			       		   byval v2 as FBSYMBOL PTR, _
			       		   byval val2 as FBVALUE ptr ) static

	dim as ASTNODE ptr expr1, expr2, expr

	'' bop
	expr1 = astNewVAR( v1, 0, dtype )

	if( v2 <> NULL ) then
		expr2 = astNewVAR( v2, 0, dtype )
	else
		select case as const dtype
		case IR_DATATYPE_LONGINT, IR_DATATYPE_ULONGINT
			expr2 = astNewCONST64( val2->long, dtype )
		case IR_DATATYPE_SINGLE, IR_DATATYPE_DOUBLE
			expr2 = astNewCONSTf( val2->float, dtype )
		case else
			expr2 = astNewCONSTi( val2->int, dtype )
		end select
	end if

	expr = astNewBOP( op, expr1, expr2 )

	'' assign
	expr1 = astNewVAR( v1, 0, dtype )

	expr = astNewASSIGN( expr1, expr )

	''
	astAdd( expr )

end sub

'':::::
''ForStatement    =   FOR ID '=' Expression TO Expression (STEP Expression)? Comment? SttSeparator
''					  SimpleLine*
''					  NEXT ID? .
''
function cForStatement as integer
    dim as integer iscomplex, ispositive, isconst
    dim as FBSYMBOL ptr il, tl, el, cl, c2l
    dim as FBSYMBOL ptr cnt, endc, stp
    dim as FBVALUE sval, eval, ival
    dim as ASTNODE ptr idexpr, expr
    dim as integer op, dtype, dclass, typ, lastcompstmt
    dim as FBCMPSTMT oldforstmt

	function = FALSE

	'' FOR
	lexSkipToken( )

	'' ID
	if( not cVariable( idexpr ) ) then
		hReportError( FB_ERRMSG_EXPECTEDVAR )
		exit function
	end if

	if( not astIsVAR( idexpr ) ) then
		hReportError( FB_ERRMSG_EXPECTEDSCALAR, TRUE )
		exit function
	end if

	cnt = astGetSymbol( idexpr )

	typ = symbGetType( cnt )

	if( (typ < FB_SYMBTYPE_BYTE) or (typ > FB_SYMBTYPE_DOUBLE) ) then
		hReportError( FB_ERRMSG_EXPECTEDSCALAR, TRUE )
		exit function
	end if

	'' =
	if( not hMatch( FB_TK_ASSIGN ) ) then
		hReportError( FB_ERRMSG_EXPECTEDEQ )
		exit function
	end if

	'' get counter type (endc and step must be the same type)
	dtype  = typ
	dclass = irGetDataClass( dtype )
	isconst = 0

    '' Expression
    if( not cExpression( expr ) ) then
    	hReportError( FB_ERRMSG_EXPECTEDEXPRESSION )
    	exit function
    end if

	''
	if( astIsCONST( expr ) ) then
		astConvertValue( expr, @ival, dtype )
		isconst += 1
	end if

	'' save initial condition into counter
	expr = astNewASSIGN( idexpr, expr )
	astAdd( expr )

	'' TO
	if( not hMatch( FB_TK_TO ) ) then
		hReportError( FB_ERRMSG_EXPECTEDTO )
		exit function
	end if

	'' end condition (Expression)
	if( not cExpression( expr ) ) then
		hReportError( FB_ERRMSG_EXPECTEDEXPRESSION )
		exit function
	end if

	''
	if( astIsCONST( expr ) ) then
		astConvertValue( expr, @eval, dtype )
		astDel( expr )
		endc = NULL
		isconst += 1

	'' store end condition into a temp var
	else
		endc = cStoreTemp( expr, dtype )
	end if

	'' STEP
	ispositive 	= TRUE
	iscomplex 	= FALSE
	if( lexGetToken( ) = FB_TK_STEP ) then
		lexSkipToken( )
		if( not cExpression( expr ) ) then
			hReportError( FB_ERRMSG_EXPECTEDEXPRESSION )
			exit function
		end if

		'' store step into a temp var
		if( astIsCONST( expr ) ) then
			select case as const astGetDataType( expr )
			case IR_DATATYPE_LONGINT, IR_DATATYPE_ULONGINT
				ispositive = (astGetValLong( expr ) >= 0)
			case IR_DATATYPE_SINGLE, IR_DATATYPE_DOUBLE
				ispositive = (astGetValFloat( expr ) >= 0)
			case else
				ispositive = (astGetValInt( expr ) >= 0)
			end select
		else
			iscomplex = TRUE
		end if

		if( iscomplex ) then

			stp = symbAddTempVar( typ )
			if( stp = NULL ) then
				exit function
			end if

			astAdd( astNewASSIGN( astNewVAR( stp, 0, dtype ), expr ) )

		else
            '' get constant step
            astConvertValue( expr, @sval, dtype )
			astDel( expr )
			stp = NULL
			isconst += 1
		end if

	else
		select case as const dtype
		case IR_DATATYPE_LONGINT, IR_DATATYPE_ULONGINT
			sval.long = 1
		case IR_DATATYPE_SINGLE, IR_DATATYPE_DOUBLE
			sval.float = 1.0
		case else
			sval.int = 1
		end select
		stp = NULL
		isconst += 1
	end if

	'' labels
    tl = symbAddLabel( NULL )
	'' add comp and end label (will be used by any CONTINUE/EXIT FOR)
	cl = symbAddLabel( NULL )
	el = symbAddLabel( NULL )

    '' if inic, endc and stepc are all constants,
    '' check if this branch is needed
    if( isconst = 3 ) then

		if( ispositive ) then
			op = IR_OP_LE
    	else
			op = IR_OP_GE
    	end if

    	expr = astNewBOP( op, astNewCONST( @ival, dtype ), astNewCONST( @eval, dtype ) )
    	if( not astGetValInt( expr ) ) then
    		astAdd( astNewBRANCH( IR_OP_JMP, el ) )
    	end if
    	astDel( expr )

    else
    	astAdd( astNewBRANCH( IR_OP_JMP, tl ) )
    end if

	'' add start label
	il = symbAddLabel( NULL )
	astAdd( astNewLABEL( il ) )

	'' save old for stmt info
	oldforstmt = env.forstmt

	env.forstmt.cmplabel = cl
	env.forstmt.endlabel = el

	''
	lastcompstmt = env.lastcompound
	env.lastcompound = FB_TK_FOR

	'' Comment?
	cComment( )

	'' separator
	if( not cStmtSeparator( ) ) then
		hReportError( FB_ERRMSG_EXPECTEDEOL )
		exit function
	end if

	'' loop body
	do
		if( not cSimpleLine( ) ) then
			exit do
		end if
	loop while( lexGetToken( ) <> FB_TK_EOF )

	'' NEXT
	if( not hMatch( FB_TK_NEXT ) ) then
		hReportError( FB_ERRMSG_EXPECTEDNEXT )
		exit function
	end if

	'' counter?
	if( lexGetClass( ) = FB_TKCLASS_IDENTIFIER ) then
		lexSkipToken( )

		'' ( ',' counter? )*
		if( lexGetToken( ) = CHAR_COMMA ) then
			'' hack to handle multiple identifiers...
			lexSetToken( FB_TK_NEXT, FB_TKCLASS_KEYWORD )
		end if
	end if

	'' cmp label
	astAdd( astNewLABEL( cl ) )

	'' counter += step
	cFlushSelfBOP( IR_OP_ADD, dtype, cnt, stp, @sval )

	'' test label
	astAdd( astNewLABEL( tl ) )

    if( not iscomplex ) then

		if( ispositive ) then
			op = IR_OP_LE
    	else
			op = IR_OP_GE
    	end if

    	'' counter <= or >= end cond?
		cFlushBOP( op, dtype, cnt, NULL, endc, @eval, il )

		c2l = NULL
    else
		c2l = symbAddLabel( NULL )

    	'' test step sign and branch
		select case as const dtype
		case IR_DATATYPE_LONGINT, IR_DATATYPE_ULONGINT
			ival.long = 0
		case IR_DATATYPE_SINGLE, IR_DATATYPE_DOUBLE
			ival.float = 0.0
		case else
			ival.int = 0
		end select

		cFlushBOP( IR_OP_GE, dtype, stp, @sval, NULL, @ival, c2l )

    	'' negative, loop if >=
		cFlushBOP( IR_OP_GE, dtype, cnt, NULL, endc, @eval, il )
		'' exit loop
		astAdd( astNewBRANCH( IR_OP_JMP, el ) )
    	'' control label
    	astAdd( astNewLABEL( c2l, FALSE ) )
    	'' positive, loop if <=
		cFlushBOP( IR_OP_LE, dtype, cnt, NULL, endc, @eval, il )
    end if

    '' end label (loop exit)
    astAdd( astNewLABEL( el ) )

	'' restore old for stmt info
	env.forstmt = oldforstmt

	''
	env.lastcompound = lastcompstmt

	function = TRUE

end function

