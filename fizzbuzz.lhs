\documentclass{tmr}

%include polycode.fmt

\newcommand{\Skip}{\textsc{Skip}}
\newcommand{\Halt}{\textsc{Halt}}
\newcommand{\Print}{\textsc{Print}}
\newcommand{\Abort}{\textsc{Abort}}
\newcommand{\scolon}{ ;\; }
\newcommand{\sep}{\ \vert\ }
\newcommand{\sem}[1]{[\![ #1 ]\!]}
\newcommand{\ahole}{\bullet}
\newcommand{\cont}[1]{\langle #1 \rangle}
\newcommand{\fizz}{\textit{fizz}}
\newcommand{\buzz}{\textit{buzz}}
\newcommand{\default}{\textit{base}}

\title{FizzBuzz in Haskell by Embedding a~Domain-Specific Language: A~Tutorial}
\author{Maciej Pir{\'o}g\email{maciej.adam.pirog@@gmail.com}}

\begin{document}

\begin{introduction}
  The FizzBuzz problem is simple but not trivial, which makes it a
  popular puzzle during job interviews for software developers. The
  conundrum lies in a peculiar but not unusual control-flow scenario:
  the default action is executed only if some previous actions were
  not executed. In this tutorial we ask if we can accomplish this
  without having to check the conditions for the previous actions
  twice; in other words, if we can make the control flow follow the
  information flow without loosing modularity. And the contest is for
  beauty of the code.

  We deliver a rather non-standard, and a bit tongue-in-cheek
  solution. First, we design a drastically simple domain-specific
  language (DSL), which we call, after the three commands of the
  language, Skip-Halt-Print. For each natural number $n$, we devise a
  Skip-Halt-Print program that solves FizzBuzz for $n$.  Then, we
  implement this in Haskell, and through a couple of simple
  transformations we obtain the final program.  The corollary is a
  reminder of the importance of higher-order functions in every
  functional programmer's toolbox.
\end{introduction}

\section{The FizzBuzz problem}

FizzBuzz is a simple game for children, and therefore a really hard
nut to crack for programmers and computer scientists. To quote the
rules~\cite{wiki}:
%
\begin{quote}
 Players generally sit in a circle. The player designated to go first
 says the number `$1$', and each player thenceforth counts one number
 in turn. However, any number divisible by three is replaced by the
 word \textit{fizz} and any divisible by five by the word
 \textit{buzz}. Numbers divisible by both become \textit{fizzbuzz}.
\end{quote}
%
In this tutorial, we focus on a single step of the game, that is to
convert a natural number $n$ into \textit{fizz}, \textit{buzz},
\textit{fizzbuzz}, or its string representation.

There are a lot of solutions floating around the Internet, but most of
them are, from our point of view, unsatisfactory. Exhibit A:
%
\begin{code}
fizzbuzz :: Int -> String
fizzbuzz n =
  if n `mod` 3 == 0 && n `mod` 5 == 0 then
    "fizzbuzz"
  else if n `mod` 3 == 0 then
    "fizz"
  else if n `mod` 5 == 0 then
    "buzz"
  else
    show n
\end{code}
%
Exhibit B:
%
\begin{code}
fizzbuzz n :: Int -> String
fizzbuzz n =
  if n `mod` 3 == 0
    then "fizz" ++  if n `mod` 5 == 0
                      then "buzz"
                      else ""
    else  if n `mod` 5 == 0
            then "buzz"
            else show n 
\end{code}
%
Though both programs are correct with respect to the specification,
Exhibit A, in some cases, performs the |`mod` 3| and |`mod` 5| tests
more than once, while Exhibit~B disperses the \textit{buzzing} code
into more than one place in the program. Meanwhile, we want there to
be at most one place that outputs \textit{fizz}, \textit{buzz}, or the
string representation, and each test to be performed only
once. Outputting \textit{fizzbuzz} should be done by executing the
(one and only) piece of code that outputs \textit{fizz}, followed by
the (one and only) piece that outputs \textit{buzz}. That is because
\textit{fizzing} and \textit{buzzing} are two separate activities --
consider the FizzBuzzHissHowl problem, where \textit{hiss} and
\textit{howl} are printed for multiples of $7$ and $11$
respectively. The program design of Exhibit A and B would lead to an
explosion of code complexity.

We can examine the output itself, which gives us an opportunity for
yet another unsatisfactory attempt, Exhibit C:
%
%format +<+ = "\lhd"
\begin{code}
(+<+) :: String -> String -> String
""  +<+ s = s
a   +<+ s = a

fizzbuzz :: Int -> String
fizzbuzz n  =    ((  if n `mod` 3 == 0 then "fizz" else "")
               ++    if n `mod` 5 == 0 then "buzz" else "")
               +<+   show n 
\end{code}
%
The problem with this solution is far more subtle; some might even say
that it is simple and elegant. Be that as it may, we do not like the
fact that the |+<+| operator has to check if its first argument is
empty. After all, we have already checked the conditions |`mod` 3| and
|`mod` 5|, so the third test (|+<+|'s pattern matching) seems
redundant from the information-flow point of view (compare Exhibit B,
which always performs only two tests).

So, is out there a program that reflects the information-flow
structure as Exhibit~B, but, at the same time, is as modular as
Exhibit C?  Let's find out!

\section{Skip-Halt-Print and contexts}

If one feels overwhelmed by the number of (better or worse) possible
ways to solve such a simple problem as FizzBuzz in Haskell, they can
start with a simpler language. The one we propose is called
Skip-Halt-Print, and it is very imperative.

A program in Skip-Halt-Print is a (possibly empty) list of commands,
which are executed sequentially. There are only three different
commands:
\begin{itemize}
\item $\Skip$ is an idle instruction; it does nothing at all;
\item $\Halt$ stops the computation; the rest of the program is not
executed;
\item $\Print\ \texttt{s}$ prints out the string $\texttt{s}$.
\end{itemize}
More formally, the syntax is given by the following grammar, where $c$
denotes commands, $p$ denotes programs, and $\epsilon$ is the empty
program:
%
\begin{align*}
 c \ &{:}{:}{=} \ \Skip \sep \Halt \sep \Print\ \texttt{s} \\
 p \ &{:}{:}{=} \ c \scolon p \sep \epsilon
\end{align*}
%
For brevity, we will give $\texttt{s}$ also as an integer literal with
implicit conversion. For example, the command $\Print\ 42$ is meant to
print out the string of characters \texttt{42}.

The formal semantics can be given by a denotation function $\sem{{-}}
: p \rightarrow \textit{String}$, where $\textit{String}$ is the set
of all strings of characters. In the following, |++| denotes
concatenation and $\texttt{""}$ denotes the empty string.
%
\begin{align*}
\sem{\Skip \scolon p} &= \sem{p} \\
\sem{\Halt \scolon p} = \sem{\epsilon} &= \texttt{""} \\
\sem{\Print\ \texttt{s} \scolon p} &= \texttt{s}\, \text{|++|}\, \sem{p}
\end{align*}
%
For example:
%
\begin{align*}
\sem{\Print\ \texttt{"studio"} \scolon \Skip \scolon \Print\ 54} &= \texttt{studio54} \\
\sem{\Print\ \texttt{"nuts"} \scolon \Halt \scolon \Print\ \texttt{"and bolts"}} &= \texttt{nuts} \\
\end{align*}

For every natural number $n$, we construct a Skip-Halt-Print program
that solves FizzBuzz for $n$. The building blocks for this
construction are called \textit{contexts} -- they are programs with
holes (one hole per context). We denote contexts by putting angle
brackets $\cont{{-}}$ around the programs, while holes are denoted by
the $\ahole$ symbol. For example:
%
\begin{align*}
\cont{\Print\ \texttt{"keep"} \scolon \ahole \scolon \Print\ \texttt{"calm"}}
\end{align*}
%
A hole is a place in which we can stick another program, and get a new
program as a result. We denote this operation by juxtaposition:
%
\begin{align*}
&\cont{ \Print\ \texttt{"keep"} \scolon \ahole \scolon \Print\ \texttt{"calm"}}
\; (\Print\ \texttt{"nervous and never"})\\
=\ &
\Print\ \texttt{"keep"} \scolon \Print\ \texttt{"nervous and never"} \scolon \Print\ \texttt{"calm"}
\end{align*}
%
Two contexts can be composed, and for that we use the $\circ$
symbol:
%
\begin{align*}
&\cont{ \Skip \scolon \ahole \scolon \Print\ 0} \circ \cont{ \Halt \scolon \ahole }\\
=\ &
\cont{ \Skip \scolon \Halt \scolon \ahole \scolon \Print\ 0}
\end{align*}

What does the FizzBuzz program do? Basically, it prints out $n$,
unless something else (like \textit{fizzing} or \textit{buzzing})
happens. This behaviour is captured by the following context:
%
\begin{equation*}
\default (n) = \cont{ \ahole \scolon \Print\ n }
\end{equation*}
%
What about \textit{fizzing}? If only $n$ is divisible by 3, it prints
out $\texttt{fizz}$, but it also needs to prevent the default action
from happening by $\Halt$-ing the computation. In between $\Print$-ing
and $\Halt$-ing anything (like \textit{buzzing}) can happen:
%
\begin{equation*}
\fizz (n) = \begin{cases} \cont{ \Print\ \texttt{"fizz"} \scolon \ahole \scolon \Halt
 } & \text{if $n \operatorname{mod} 3 = 0$}\\ \cont{ \ahole } & \text{otherwise}\end{cases}
\end{equation*}
%
The context for \textit{buzzing} is analogous:
%
\begin{equation*}
\buzz (n) = \begin{cases} \cont{ \Print\ \texttt{"buzz"} \scolon \ahole \scolon \Halt
 } & \text{if $n \operatorname{mod} 5 = 0$}\\ \cont{ \ahole } & \text{otherwise}\end{cases}
\end{equation*}

The program that solves FizzBuzz for $n$, which we call $fb(n)$, is a
composition of all these contexts, which we cork with $\Skip$:
%
\begin{equation*}
\mathit{fb}(n) = (\default(n) \circ \fizz(n) \circ \buzz(n)) \; \Skip
\end{equation*}
%
Examples:
%
\begin{align*}
\mathit{fb}(1) &= \Skip \scolon \Print\ 1 \\
\mathit{fb}(3) &= \Print\ \texttt{"fizz"} \scolon \Skip \scolon \Halt \scolon \Print\ 3 \\ 
\mathit{fb}(5) &= \Print\ \texttt{"buzz"} \scolon \Skip \scolon \Halt \scolon \Print\ 5 \\ 
\mathit{fb}(15) &= \Print\ \texttt{"fizz"} \scolon \Print\ \texttt{"buzz"} \scolon 
\Skip \scolon \Halt \scolon \Halt \scolon \Print\ 15 \\ 
\end{align*}

\begin{exercise}
  For any natural number $n$, give a Skip-Halt-Print program that
  solves the FizzBuzzHissHowl problem for $n$.
\end{exercise}

\begin{exercise}
  What is the formal definition of the operations on contexts
  described above?  Show that contexts with composition form a monoid,
  that is $\circ$ is associative, $(f \circ g) \circ h = f \circ (g
  \circ h)$, and $\cont{ \ahole }$ is its left and right unit, $\cont{
    \ahole } \circ f = f$ and $f \circ \cont{ \ahole } = f$
  respectively.
\end{exercise}


\section{Haskell implementation}

Now, to solve FizzBuzz in Haskell, we implement Skip-Halt-Print, both
syntax and semantics, together with the language of contexts. For each
$n$, we construct the right composition of contexts as described
above, and then execute the resulting program.

Then, we apply a series of algebraic transformations that simplify the
code into our proposed solution. By ``algebraic'' we mean
transformations that depend only on local properties of the
components, without the actual understanding of the implemented
algorithm. Something that can be deduced solely from the shape of the
code, like the |fold| pattern, and applied by simple equational
calculation.

\subsection{Direct definition}

The commands of Skip-Halt-Print are implemented as a three-constructor
data type |Cmd|, and the program is, of course, a list of commands. We
call the $\sem{{-}}$ function |interp|.
%
\begin{code}
data Cmd      = Skip | Halt | Print String
type Program  = [Cmd]

interp :: Program -> String
interp (Skip     : xs  )   = interp xs
interp (Halt     : xs  )   = ""
interp (Print s  : xs  )   = s ++ interp xs
interp []                  = ""
\end{code}
%
Contexts are more tricky. Instead of specifying their syntax and
operations, we encode them as functions from programs to programs
(this technique is sometimes called \textit{higher-order abstract
  syntax}). In this case, sticking the program in a context becomes
Haskell's function application, and the composition of contexts
becomes simply Haskell's $\circ$. Note, though, that not every Haskell
function of the type |Program -> Program| is a valid context in the sense
specified in the previous section.
%
\begin{code}
type Cont = Program -> Program

fizz, buzz, base :: Int -> Cont
fizz  n  | n `mod` 3  == 0  = \x -> [Print "fizz"] ++ x ++ [Halt]
         | otherwise        = id
buzz  n  | n `mod` 5  == 0  = \x -> [Print "buzz"] ++ x ++ [Halt]
         | otherwise        = id
base  n                     = \x -> x ++ [Print (show n)]

fb :: Int -> Program
fb n = (base n . fizz n . buzz n) [Skip]

fizzbuzz :: Int -> String
fizzbuzz n = interp (fb n)
\end{code}

\subsection{Interpretation is a fold}

So, to solve FizzBuzz for |n|, we first build a program (a
datastructure), and then interpret it (by traversing the
datastructure). This calls for some deforestation, that is removal of
the intermediate structures! First, we notice a known pattern here:
|interp| is a fold. We can rewrite it as follows:
%
\begin{code}
step :: Cmd -> String -> String
step Skip       t  = t
step Halt       t  = ""
step (Print s)  t  = s ++ t

interp = foldr step ""
\end{code}
%
Additionally, |foldr| has the following property (see
Exercise~\ref{property}):
%
\begin{code}
foldr step "" p = foldr (.) id (fmap step p) ""
\end{code}
%
So, instead of writing programs like

> [Skip, Halt, Print "c"]

and interpreting them by folding with |step|, we can write programs
like

>[step Skip, step Halt, step (Print "c")]

and interpret them by folding $\circ$. Also, we can inline the
definition of |step|:

\begin{code}
   [step Skip, step Halt, step (Print "c")]

=  [\t -> t, \t -> "", \t -> "c" ++ t]

=  [id, const "", ("c"++)]
\end{code}

Why building and then interpreting? We can manually deforest the
situation by fusing the two: instead of

> foldr (.) id [id, const, ("c"++)]

we write

> id . const. ("c"++)

In summary, we can define the next version of Skip-Halt-Print commands
as follows:
%
\savecolumns
\begin{code}
type Program = String -> String

skip, halt  :: Program
skip   = id
halt   = const ""

print       :: String -> Program
print  = (++)
\end{code}
%
Now, our programs look like this:
\begin{code}
print "hello" . skip . print "world" . halt
\end{code}
%
To execute them, we apply them to an empty string, for example:
%
\begin{code}
(print "hello" . skip . print "world" . halt) "" = "helloworld"
\end{code}
%
We need to accordingly adjust the bodies of our contexts:
%
\restorecolumns
\begin{code}
type Cont = Program -> Program

fizz, buzz, base :: Int -> Cont
fizz  n  | n `mod` 3  == 0  = \x -> print "fizz" . x . halt
         | otherwise        = id
buzz  n  | n `mod` 5  == 0  = \x -> print "buzz" . x . halt
         | otherwise        = id
base  n                     = \x -> x . print (show n)

fizzbuzz :: Int -> String
fizzbuzz n = (base n . fizz n . buzz n) skip ""
\end{code}
%
Notice that $\circ$ is now overloaded: it composes both programs from
commands (as in the bodies of functions |fizz|, |buzz|, and |base|)
and contexts (as in the body of |fizzbuzz|).

\subsection{Inlining}

The truth is that we do not need to implement the entire
Skip-Halt-Print language to solve FizzBuzz -- our three contexts
suffice. Thus, we inline the definitions of |base|, |skip|, |halt|,
and |print| in |fizzbuzz|. We also put |fizz| and |buzz| as local
definitions, so that we don't have to pass |n| around:
%
\begin{code}
fizzbuzz :: Int -> String
fizzbuzz n = (fizz . buzz) id (show n)
 where
  fizz  | n `mod` 3  == 0  = \x -> const ("fizz" ++ x "")
        | otherwise        = id
  buzz  | n `mod` 5  == 0  = \x -> const ("buzz" ++ x "")
        | otherwise        = id
\end{code}

\subsection{Final polishing}

As the last step, we abstract over the divisor and the printed message
in |fizz| and |buzz|:
%
\begin{code}
fizzbuzz :: Int -> String
fizzbuzz n = (test 3 "fizz" . test 5 "buzz") id (show n)
  where
    test d s x  | n `mod` d == 0  = const (s ++ x "")
                | otherwise       = x
\end{code}

What is going on in this program? The (higher-order) function |test|
has the following, longish type:

> test :: Int -> String -> (String -> String) -> String -> String

To understand its logic, it is convenient to name the last argument
and rewrite the function to the following equivalent definition:

\begin{code}
test d s x v  | n `mod` d == 0  = s ++  x ""
              | otherwise       =       x v
\end{code}

\noindent
The argument |v :: String| represents the default value of the
function (originally set by the function |fizzbuzz| to the string
representation of |n|), while |x :: String -> String| represents a
continuation -- the rest of the computation parametrised by a new
default value. If the modulo test fails, we change neither the
continuation, nor the default value. If the test succeeds, we print
out the string |s|, but also change the default value to the empty
string, so that the string representation of |n| is not printed out.

\subsection{Exercises}

\begin{exercise}\label{property}
  Prove that for |f :: t -> s -> s| and |a :: s|, the following
  equality holds:

>foldr f a xs = foldr (.) id (fmap f xs) a
\end{exercise}

\begin{exercise}
 In the ``Inlining'' step we silently performed some cleaning-up. In
 reality, a bald inlining of |base| and |skip| in |fizzbuzz| yields
%
\begin{code}
((\x -> x . (++) (show n)) . fizz . buzz) id ""
\end{code}
%
Show that it is equal to |(fizz . buzz) id (show n)|.
\end{exercise}

\begin{exercise}
 Adjust the final solution to the FizzBuzzHissHowl problem. Do you
 have to go through the entire derivation once more, or is the final
 solution modular?
\end{exercise}

\section{Summary}

To solve a trivial problem, we went through a bit of a hassle: formal
language design and semantics, embedded DSLs, interpreters,
higher-order abstract syntax to implement contexts, algebra of
programming in the form of reasoning about folds. One might also argue
that the obtained solution is not too intuitive. Do we really need
such heavy artillery to solve FizzBuzz?

Though this tutorial is not meant to be dead serious, and is mostly a
pretext for some fun with the functional programming technologies
listed above -- also, going through this derivation might be a risky
move during a job interview -- there is a small point it wants to
convey: \emph{Functional programmers! Remember higher-order
  functions!} They are your tool to express programs with non-trivial
structure, to closer follow the information-flow, to dynamically build
your programs in runtime. A harsh, cantankerous functional programming
pedagogue might say that they are such a basic tool that the final
FizzBuzz program shouldn't appear complicated at all (and could be
easily written by hand) if one knows their paradigm.

\section*{Closing remarks}

The Skip-Halt-Print language is based on Edsger W. Dijkstra's
Skip-Abort, which can be found in his textbook \textit{A~Discipline of
  Programming}~\cite[Chapter 4]{discipline} (I am grateful to Tomasz
Wierzbicki for the reference.) However, one needs to be aware of a
difference in semantics between $\Halt$ and $\Abort$: the former
peacefully ends the computation (like \texttt{return} in
\textit{C}-like languages), while the latter atrociously breaks it
(like Haskell's |error| function).

I would also like to thank Jeremy Gibbons for his comments.
% 
The first idea for this tutorial sparkled in my head after Laurence
E. Day's Facebook post:
%
\begin{quote}
 I can write doctoral level Haskell without so much as missing a
 beat, but I'd have a genuinely hard time writing a FizzBuzz program
 in Java.
\end{quote}
%
The main point of this tutorial is that FizzBuzz is \textbf{not at all
trivial}, but, many thanks to higher-order functions in Haskell,
solvable. I don't know about Java.

\bibliography{fizzbuzz}


\end{document}
