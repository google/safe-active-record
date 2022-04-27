# Safe Active Record

A security middleware to defend against SQLi in Ruby Active Record.

This middleware decorates unsafe Active Record query APIs to enforce SQL strings
created from secure-by-construction types.

## Secure-by-construction

In a classic SQLi case, user supplied untrusted input is often mixed in with SQL
queries through string concatenation or interpolation. Most of the times, these
vulnerable injectable SQL string can be rewritten securely to string literals
with parametrized queries as placeholders for user inputs. If this string
literal contract can be enforced most of the time, the bar to make SQLi mistake
is much higher, and developers and product security engineers would only need to
spend time on those rare exception cases in code review/audit.

In some static typed languages, constant string type can be used to enforce the
above mentioned contract, but Ruby is a dynamically typed language. While there
is such thing as class Constant in Ruby, the syntax requirement to define them
in a class scope make them far away from query API invocation sites, deviating
much from developers' habits.

Ruby Symbol is an immutable type that can be used to approximate constant string
literals, with the exception that a symbol can be created at runtime (e.g.
`"xyz".to_sym`. However, symbols written in their literal format (e.g.
`:symbol`) are loaded into `Symbol.all_symbols` array at the code load time.
This means that with `eager_load` feature enabled (typical in Rails apps), a
niche point can be found during apps boot time so that all existing symbols can
approximate safe string literals, whose creation proceeds any unsafe
construction (e.g. `"where id = #{id}".to_sym`). This enables the enforcement of
Symbol type as the safe input type to ActiveRecord query APIs.

The enforcement of the contracted type is done by decorating those query APIs
that are subject to SQLi, and banning String type input. As some original APIs
already distinguish Symbol and String type inputs, Symbol is warpped into a new
trusted type under the safe contract to avoid confusion internally. The trusted
type can only be constructed from a safe symbol thus achieving
secure-by-construction.

## Setup

`SafeActiveRecord.activate!` needs to be called before an application starts to
process user input, but after earger loading finishes, so that a snapshot of
safe symbols can be taken. In a rails app, it can done at
[config.after_initialize](https://guides.rubyonrails.org/configuring.html#config-after-initialize).

The method takes in a hash into which a few options can be passed:

*   `safe_query_mode`: `:strict` or `:lax`; `:lax` mode allows usage of
    `RiskilyAssumeTrustedString` type.
*   `dry_run`: true/false, default to false; when set to true, only warnings
    will be emitted but otherwise an exception will be raised when uncomforming
    types are passed in.
*   `intercept_load`: true/false, default to false; when set to true,
    `require`/`load`/`require_relative` will be intercepted in order to
    calculate the delta of symbols created during new Ruby source code loading,
    and add them to the trusted symbol set. This is to compensate for use cases
    when eager_load is turned off, typically during local development. See
    limitation section for the caveats.

    For instance:

    ```
     config.after_initialize do
         SafeActiveRecord.activate!({ intercept_load: !config.eager_load })
     end
    ```

## Safe types

Three new types are consider safe types under the new contract:

*   TrustedSymbol: the secure-by-construction type that takes in a safe symbol.
    Most SQL string should be rewritten to this type.
*   UncheckedString: escaping type that assumes the input is fully trusted. In
    very few cases, SQL query can't be constructed from string literals and the
    usage of such a type should raise a signal for security code review.
*   RiskilyAssumeTrustedString: similar to UncheckedString but should only be
    used during adoption of SafeActiveRecord when certain rewriting takes
    substantial efforts.

    An old SQL

    ```
    Obj.where("select * from table where user = #{id}")
    ```

    would need to be rewitten to

    ```
    Obj.where(SafeActiveRecord::TrustedSymbol.new(:'select * from table where user
    = ?'), id)
    ```

## Limitation

`intercept_load` mode is unfortunately not thread safe and could lead to unsafe
symbols being treated as trusted in the worst case. It's only a compatible mode
to support local development that truns off eager load to expedite development
velocity, and it should never be enabled for production where concurrency is
controllable by a malicious user.
