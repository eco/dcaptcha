/// A CAPTCHA generator for D services.
/// Written in the D programming language.

module dcaptcha.dcaptcha;

import std.algorithm;
import std.conv;
import std.exception;
import std.random;
import std.range;
import std.string;

import ae.utils.array;

import dcaptcha.markov;

struct Challenge
{
	string question, code;
	string[] answers;
}

Challenge getCaptcha()
{
	string[] identifiers = 26.iota.map!(l => [cast(char)('a'+l)].assumeUnique()).array();
	identifiers ~= "foo, bar, baz".split(", ");
	//identifiers ~= "qux, quux, corge, grault, garply, waldo, fred, plugh, xyzzy, thud".split(", ");

	string[] mathOperators = "+ - / * %".split();

	Challenge challenge;
	with (challenge)
		[
			// Identify syntax
			{
				question = "What is the name of the D language syntax feature illustrated in the following fragment of D code?";
				[
					// lambda
					{
						code =
							q{
								(A, B) => A @ B
							}.outdent().strip()
							.replace("A", identifiers.pluck)
							.replace("B", identifiers.pluck)
							.replace("@", mathOperators.pluck)
						;
						answers = cartesianJoin(["lambda", "lambda function", "anonymous function"], ["", " literal"]);
					},
					// static destructor
					{
						string bye = ["Bye", "Goodbye", "Shutting down", "Exiting"].sample ~ ["", ".", "...", "!"].sample;
						code =
							q{
								static ~this() { writeln("BYE"); }
							}.outdent().strip()
							.replace("BYE", bye)
						;
						answers = ["static destructor", "module destructor", "thread destructor"];
					},
					// nested comments
					{
						code =
							q{
								/+ A = B @ C; /+ A = X; +/ +/
							}.outdent().strip()
							.replace("A", identifiers.pluck)
							.replace("B", identifiers.pluck)
							.replace("C", identifiers.pluck)
							.replace("X", uniform(10, 100).text)
							.replace("@", mathOperators.pluck)
						;
						answers = cartesianJoin(["nested ", "nesting "], ["", "block "], ["comment", "comments"]);
					},
					// anonymous nested classes
					{
						code =
							q{
								auto A = new class O {};
							}.outdent().strip()
							.replace("A", identifiers.pluck)
							.replace("O", identifiers.pluck.toUpper)
						;
						answers = cartesianJoin(["anonymous "], ["", "nested "], ["class", "classes"]);
					},
					// delimited (heredoc) strings
					{
						auto delimiter = ["EOF", "DELIM", "STR", "QUOT", "MARK"].sample;
						code =
							q{
								string A = TEXT;
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("TEXT", `q"` ~ delimiter ~ "\n" ~ MarkovChain!2.query().join(" ").wrap(50).strip() ~ "\n" ~ delimiter ~ `"`)
						;
						answers = cartesianJoin(["", "multiline ", "multi-line "], ["delimited", "heredoc"], ["", " string", " strings"]);
					},
					// hex strings
					{
						auto hex =
							uniform(3, 5)
							.iota
							.map!(i => "xX".sample)
							.map!(f =>
								[1, 2, 4].sample
								.iota
								.map!(j =>
									format("%02" ~ f, uniform(0, 0x100))
								)
								.join("")
							)
							.join(" ");
						code =
							q{
								string A = x"CC";
							}.outdent().strip()
							.replace("A", identifiers.pluck)
							.replace("CC", hex)
						;
						answers = cartesianJoin(["hex", "hex ", "hexadecimal "], ["string", "strings"]);
					},
					// associative arrays
					{
						string[] types = ["int", "string"];
						code =
							q{
								T[U] A;
							}.outdent().strip()
							.replace("A", identifiers.pluck)
							.replace("T", types.sample)
							.replace("U", types.sample)
						;
						answers = ["AA", "associative array", "hashmap"];
					},
					// array slicing
					{
						code =
							q{
								A = B[X..Y];
							}.outdent().strip()
							.replace("A", identifiers.pluck)
							.replace("B", identifiers.pluck)
							.replace("X", uniform(0, 5).text)
							.replace("Y", uniform(5, 10).text)
						;
						answers = cartesianJoin(["", "array "], ["slice", "slicing"]);
					},
				].sample()();
			},
			// Calculate function result
			// (use syntax that only programmers should be familiar with)
			{
				question = "What will be the return value of the following function?";
				[
					// Modulo operator (%)
					{
						int x = uniform(10, 50);
						int y = uniform(x/4, x/2);
						code =
							q{
								int F() { int A = X; A %= Y; return A; }
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("A", identifiers.pluck)
							.replace("X", x.text)
							.replace("Y", y.text)
						;
						answers = [(x % y).text];
					},
					// Integer division, increment
					{
						int y = uniform(2, 5);
						int x = uniform(5, 50/y) * y + uniform(1, y);
						int sign = uniform(0, 2) ? -1 : 1;
						code =
							q{
								int F() { int A = X, B = Y; B@@; A /= B; return A; }
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("A", identifiers.pluck)
							.replace("B", identifiers.pluck)
							.replace("X", x.text)
							.replace("Y", (y - sign).text)
							.replace("@", sign > 0 ? "+" : "-")
						;
						answers = [(x / y).text];
					},
					// Ternary operator + division/modulo
					{
						int x = uniform(10, 50);
						int y = uniform(2, 4);
						int a = uniform(10, 50);
						int b = uniform(2, a/2);
						int c = uniform(10, 50);
						int d = uniform(2, c/2);
						code =
							q{
								int F() { return X % Y ? A / B : C % D; }
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("X", x.text)
							.replace("Y", y.text)
							.replace("A", a.text)
							.replace("B", b.text)
							.replace("C", c.text)
							.replace("D", d.text)
						;
						answers = [(x % y ? a / b : c % d).text];
					},
					// Formatting, hexadecimal numbers
					{
						int n = uniform(20, 100);
						n &= ~7;
						int w = uniform(2, 8);
						string id = identifiers.pluck;
						code =
							q{
								string F() { return format("A=%0WX", N); }
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("A", id)
							.replace("N", n.text)
							.replace("W", w.text)
						;
						answers = [format("%s=%0*X", id, w, n)];
						answers ~= answers.map!(s => `"`~s~`"`).array();
					},
					// iota+reduce - max
					{
						int x = uniform(10, 100);
						code =
							q{
								int F() { return iota(X).reduce!max; }
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("X", x.text)
						;
						answers = [(x - 1).text];
					},
					// iota+reduce - sum
					{
						int x = uniform(3, 10);
						code =
							q{
								int F() { return iota(X).reduce!"a+b"; }
							}.outdent().strip()
							.replace("F", identifiers.pluck)
							.replace("X", x.text)
						;
						answers = [(iota(x).reduce!"a+b").text];
					},
				].sample()();
			},
		].sample()();
	return challenge;
}

private string[] cartesianJoin(PARTS...)(PARTS parts)
{
	return cartesianProduct(parts).map!(t => join([t.expand])).array();
}

version(dcaptcha_main)
void main()
{
	import std.stdio;
	auto challenge = getCaptcha();
	writeln("Question:");
	writeln(challenge.question);
	writeln();
	writeln(challenge.code);
	writeln();
	writeln("Answers:");
	foreach (n, answer; challenge.answers)
		writeln(n+1, ". ", answer);
}