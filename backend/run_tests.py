"""
Quick test runner script for MEWallet backend tests
"""
import subprocess
import sys


def run_all_tests():
    """Run all tests with coverage"""
    print("🧪 Running all tests with coverage...\n")
    result = subprocess.run([
        "pytest",
        "-v",
        "--cov=.",
        "--cov-report=term-missing",
        "--cov-report=html"
    ])
    return result.returncode


def run_specific_tests(test_file):
    """Run specific test file"""
    print(f"🧪 Running tests in {test_file}...\n")
    result = subprocess.run([
        "pytest",
        f"tests/{test_file}",
        "-v"
    ])
    return result.returncode


def run_with_pdb():
    """Run tests with debugger"""
    print("🐛 Running tests with debugger...\n")
    result = subprocess.run([
        "pytest",
        "--pdb",
        "-v"
    ])
    return result.returncode


def run_last_failed():
    """Run only last failed tests"""
    print("🔄 Running last failed tests...\n")
    result = subprocess.run([
        "pytest",
        "--lf",
        "-v"
    ])
    return result.returncode


def show_coverage():
    """Open coverage report in browser"""
    import webbrowser
    import os
    
    coverage_file = "htmlcov/index.html"
    if os.path.exists(coverage_file):
        print("📊 Opening coverage report...\n")
        webbrowser.open(f"file://{os.path.abspath(coverage_file)}")
    else:
        print("❌ Coverage report not found. Run tests with coverage first.\n")


def main():
    """Main test runner menu"""
    print("=" * 50)
    print("MEWallet Backend Test Runner")
    print("=" * 50)
    print("\nOptions:")
    print("1. Run all tests with coverage")
    print("2. Run user routes tests")
    print("3. Run merchant routes tests")
    print("4. Run transaction routes tests")
    print("5. Run pay request routes tests")
    print("6. Run OAuth routes tests")
    print("7. Run with debugger (pdb)")
    print("8. Run last failed tests")
    print("9. Show coverage report")
    print("0. Exit")
    print("=" * 50)
    
    choice = input("\nEnter your choice (0-9): ").strip()
    
    if choice == "1":
        exit_code = run_all_tests()
    elif choice == "2":
        exit_code = run_specific_tests("test_user_routes.py")
    elif choice == "3":
        exit_code = run_specific_tests("test_merchant_routes.py")
    elif choice == "4":
        exit_code = run_specific_tests("test_transaction_routes.py")
    elif choice == "5":
        exit_code = run_specific_tests("test_pay_request_routes.py")
    elif choice == "6":
        exit_code = run_specific_tests("test_oauth_routes.py")
    elif choice == "7":
        exit_code = run_with_pdb()
    elif choice == "8":
        exit_code = run_last_failed()
    elif choice == "9":
        show_coverage()
        exit_code = 0
    elif choice == "0":
        print("👋 Goodbye!")
        sys.exit(0)
    else:
        print("❌ Invalid choice!")
        sys.exit(1)
    
    print("\n" + "=" * 50)
    if exit_code == 0:
        print("✅ Tests completed successfully!")
    else:
        print("❌ Some tests failed!")
    print("=" * 50)
    
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
