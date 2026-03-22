/**
 * Core calculator functions for basic arithmetic operations.
 * All functions are pure functions with no side effects.
 */

/**
 * Adds two numbers together.
 * @param a - The first number
 * @param b - The second number
 * @returns The sum of a and b
 */
export function add(a: number, b: number): number {
  return a + b;
}

/**
 * Subtracts the second number from the first.
 * @param a - The first number
 * @param b - The second number to subtract
 * @returns The difference of a and b (a - b)
 */
export function subtract(a: number, b: number): number {
  return a - b;
}

/**
 * Multiplies two numbers together.
 * @param a - The first number
 * @param b - The second number
 * @returns The product of a and b
 */
export function multiply(a: number, b: number): number {
  return a * b;
}

/**
 * Divides the first number by the second.
 * @param a - The dividend
 * @param b - The divisor
 * @returns The quotient of a and b (a / b)
 * @throws Error if b is zero (division by zero is not allowed)
 */
export function divide(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Division by zero is not allowed");
  }
  return a / b;
}
