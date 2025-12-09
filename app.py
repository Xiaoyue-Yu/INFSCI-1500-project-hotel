from flask import Flask, render_template, request, redirect, url_for, flash, session
import mysql.connector
from flask_bcrypt import Bcrypt
from datetime import datetime, date

app = Flask(__name__)
app.secret_key = 'super_secret_key'

# Initialize Bcrypt for password hashing
bcrypt = Bcrypt(app)

# Database Configuration
db_config = {
    'user': 'root',
    'password': 'Sunboy-5',  # TODO: Update with your local MySQL password
    'host': 'localhost',
    'database': 'hotel_project'
}


def get_db_connection():
    # mysql-connector uses autocommit=False by default; we rely on implicit transactions
    return mysql.connector.connect(**db_config)


def get_discount_multiplier_for_user(user_id: int, conn) -> float:
    """
    Return a discount multiplier for the guest (e.g., 0.95 means 5% off).
    Compatibility:
      - If DB stores 0.95 -> treat as multiplier 0.95
      - If DB stores 0.10 (10% off) -> convert to 0.90
    """
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT mt.discount_rate
            FROM Guests g
            JOIN Membership_Tiers mt ON g.tier_id = mt.tier_id
            WHERE g.guest_id = %s
        """, (user_id,))
        row = cur.fetchone()
        if not row or row['discount_rate'] is None:
            return 1.0
        raw = float(row['discount_rate'])
        if raw <= 0:
            return 1.0
        # Heuristic for compatibility: <=0.3 means "percent off" (e.g., 0.10 -> 10% off -> 0.90)
        if 0 < raw <= 0.3:
            return round(1.0 - raw, 4)
        # Otherwise treat as direct multiplier (e.g., 0.95)
        if 0 < raw < 1.0:
            return round(raw, 4)
        # Any other unexpected value -> no discount
        return 1.0
    except Exception:
        return 1.0


# ============================================
# Part 1. Front Page (Browsing & Sorting)
# Aggregated by Room_Types, showing available_count per type
# ============================================
@app.route('/')
def index():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    # 1. Get query parameters
    sort_order = request.args.get('sort', 'default')
    search_type = request.args.get('search_type')
    min_price = request.args.get('min_price')
    max_price = request.args.get('max_price')
    search_in = request.args.get('check_in')
    search_out = request.args.get('check_out')

    # 2. Get query params list
    query_params = []

    # 3. Construct availability subquery
    if search_in and search_out:
        availability_subquery = """
            (SELECT COUNT(*) FROM Rooms r
             WHERE r.type_id = t.type_id
             AND r.room_number NOT IN (
                SELECT res.room_number FROM Reservations res
                WHERE res.status <> 'Cancelled'
                AND res.check_in_date < %s AND res.check_out_date > %s
             )
            )
        """
        query_params.extend([search_out, search_in])
    else:
        # If no dates provided, just count 'Available' rooms
        availability_subquery = """
            (SELECT COUNT(*) FROM Rooms r
             WHERE r.type_id = t.type_id AND r.status = 'Available')
        """

    # 4. Construct main SQL query
    sql = f"""
        SELECT
            t.type_id,
            t.type_name,
            t.price,
            t.description,
            {availability_subquery} AS available_count
        FROM Room_Types t
        WHERE 1=1
    """

    # 5. Apply filters
    if search_type and search_type != '':
        sql += " AND t.type_id = %s"
        query_params.append(search_type)
    
    if min_price:
        sql += " AND t.price >= %s"
        query_params.append(min_price)
        
    if max_price:
        sql += " AND t.price <= %s"
        query_params.append(max_price)

    # 6. Apply sorting
    if sort_order == 'price_asc':
        sql += " ORDER BY t.price ASC"
    elif sort_order == 'price_desc':
        sql += " ORDER BY t.price DESC"
    else:
        sql += " ORDER BY t.type_name ASC"

    # 7. Execute query
    cursor.execute(sql, query_params)
    room_types = cursor.fetchall()

    cursor.execute("SELECT type_id, type_name FROM Room_Types ORDER BY type_id")
    all_types_dropdown = cursor.fetchall()

    # Compute discount multiplier for the logged-in guest and fetch transaction history
    discount_multiplier = 1.0
    transaction_history = []  # Initialize empty list

    if session.get('user_id') and session.get('role') == 'Guest':
        user_id = session['user_id']
        discount_multiplier = get_discount_multiplier_for_user(user_id, conn)
        history_query = """
           SELECT 
                r.reservation_id,
                r.check_in_date,
                r.check_out_date,
                r.total_price,
                r.status,
                r.room_number
            FROM Reservations r            
            WHERE r.guest_id = %s
            ORDER BY r.reservation_id DESC
        """
        cursor.execute(history_query, (user_id,))
        transaction_history = cursor.fetchall()
        print(f"--- Debug: User {user_id} History ---")
        print(f"Records found: {len(transaction_history)}")
        for item in transaction_history:
            print(item)
        print("-------------------------------------")

    conn.close()

    user_name = session.get('user_name')
    today_str = date.today().isoformat()  # for frontend <input min>

    # Pass room_types + discount + today for UI
    return render_template(
        'index.html',
        room_types=room_types,
        all_types_dropdown=all_types_dropdown,
        user_name=user_name,
        discount_multiplier=discount_multiplier,
        today=today_str,
        search_params=request.args
    )


# ============================================
# Part 2: Login (Guests & Employees)
# ============================================
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        login_id = request.form['email']
        password_candidate = request.form['password']  # Plaintext input

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # --- Step 1: Check Guests Table (by Email) ---
        query_guest = "SELECT * FROM Guests WHERE email = %s"
        cursor.execute(query_guest, (login_id,))
        guest = cursor.fetchone()

        # --- Step 2: Check Employees Table (by Username) ---
        query_employee = "SELECT * FROM Employees WHERE username = %s"
        cursor.execute(query_employee, (login_id,))
        employee = cursor.fetchone()

        conn.close()

        # --- Logic: Validate Password & Create Session ---

        # Case A: User is a Guest
        if guest:
            stored_pass = guest['password']
            password_ok = False

            # Try Plain Text Match First (Compatible with 'default_pass' or '123')
            if stored_pass == password_candidate:
                password_ok = True
            else:
                # Try Bcrypt Match (Safe guard against Invalid Salt crash)
                try:
                    if bcrypt.check_password_hash(stored_pass, password_candidate):
                        password_ok = True
                except ValueError:
                    # This happens if 'stored_pass' is not a valid hash (e.g. truncated or plain text)
                    # We treat this as a failed login attempt instead of crashing
                    pass

            if password_ok:
                session['user_id'] = guest['guest_id']
                session['user_name'] = guest['first_name']
                session['role'] = 'Guest'
                flash('Welcome back, Guest!', 'success')
                return redirect(url_for('index'))
            else:
                flash('Invalid password', 'danger')

        # Case B: User is an Employee (Admin/Staff)
        elif employee:
            stored_pass = employee['password']
            password_ok = False

            if stored_pass == password_candidate:
                password_ok = True
            else:
                try:
                    if bcrypt.check_password_hash(stored_pass, password_candidate):
                        password_ok = True
                except ValueError:
                    pass

            if password_ok:
                session['user_id'] = employee['employee_id']
                session['user_name'] = employee['username']
                session['role'] = employee['role']

                flash(f'Welcome Staff: {employee["username"]}', 'success')

                if employee['role'] == 'Manager':
                    return redirect(url_for('dashboard'))
                else:
                    return redirect(url_for('index'))
            else:
                flash('Invalid password', 'danger')

        # Case C: No user found
        else:
            flash('User not found. Please check your credentials.', 'danger')
            return redirect(url_for('login'))

    return render_template('login.html')


# ============================================
# Part 3: Logout
# ============================================
@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))


# ============================================
# Part 4: Registration (With Hashing)
# ============================================
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        email = request.form['email']
        phone = request.form['phone']
        password = request.form['password']
        confirm_password = request.form['confirm_password']
        
        # Confirm the passwords match
        if password != confirm_password:
            flash('Passwords do not match.', 'danger')
            return redirect(url_for('register'))
        # Enforce password strength
        special_characters = " !@#$%^&*()_+-=[]{};':\"\\|,.<>/?"
        
        has_lower = any(c.islower() for c in password)
        has_upper = any(c.isupper() for c in password)
        has_digit = any(c.isdigit() for c in password)
        has_special = any(c in special_characters for c in password)
        is_long_enough = len(password) >= 8

        if not (is_long_enough and has_lower and has_upper and has_digit and has_special):
            flash('Password is too weak! It must be at least 8 chars long and include uppercase, lowercase, numbers, and symbols.', 'danger')
            return redirect(url_for('register'))
        
        # Hash the password before storing
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')

        conn = get_db_connection()
        cursor = conn.cursor()

        try:
            # Default new users to Tier 2 (Member) and Role 'Guest'
            query = """
                INSERT INTO Guests (first_name, last_name, email, phone, password, tier_id, role)
                VALUES (%s, %s, %s, %s, %s, 2, 'Guest')
            """
            cursor.execute(query, (first_name, last_name, email, phone, hashed_password))
            conn.commit()
            flash('Registration successful! Please login.', 'success')
            return redirect(url_for('login'))
        except mysql.connector.Error as err:
            conn.rollback()
            flash(f'Error: {err}', 'danger')
            return redirect(url_for('register'))
        finally:
            conn.close()

    return render_template('register.html')


# ============================================
# Part 5: Booking Transaction
# User submits type_id, backend assigns the first available room of that type
# Rely on implicit transaction (autocommit=False). Do not call start_transaction().
# ============================================
@app.route('/book', methods=['POST'])
def book_room():
    # Ensure user is logged in
    if 'user_name' not in session:
        return redirect(url_for('login'))

    # Expect type_id from form instead of room_number
    type_id = request.form.get('type_id')
    check_in = request.form.get('check_in')
    check_out = request.form.get('check_out')

    if not type_id or not check_in or not check_out:
        flash('Missing booking information.', 'danger')
        return redirect(url_for('index'))

    # Validate dates and compute number of nights
    try:
        ci = datetime.strptime(check_in, '%Y-%m-%d').date()
        co = datetime.strptime(check_out, '%Y-%m-%d').date()
        # New rule: check-in cannot be in the past
        if ci < date.today():
            flash('Check-in date must be today or later.', 'danger')
            return redirect(url_for('index'))
        nights = (co - ci).days
        if nights <= 0:
            flash('Check-out date must be after check-in date.', 'danger')
            return redirect(url_for('index'))
    except ValueError:
        flash('Invalid date format. Please use YYYY-MM-DD.', 'danger')
        return redirect(url_for('index'))

    conn = get_db_connection()
    read_cur = conn.cursor(dictionary=True)  # for reading rows
    write_cur = conn.cursor()                # for writes

    try:
        # 1) Get price and type name for the room type (starts implicit transaction)
        read_cur.execute("SELECT price, type_name FROM Room_Types WHERE type_id = %s", (type_id,))
        type_row = read_cur.fetchone()
        if not type_row:
            conn.rollback()
            flash('Room type not found.', 'danger')
            return redirect(url_for('index'))

        price_per_night = float(type_row['price'])

        # 1.5) Apply membership discount (Guests only)
        discount_multiplier = 1.0
        if session.get('role') == 'Guest':
            discount_multiplier = get_discount_multiplier_for_user(session['user_id'], conn)

        # New total price with discount
        total_price = round(price_per_night * discount_multiplier * nights, 2)

        # 2) Lock a single available room to avoid overbooking under concurrency
        read_cur.execute(
            """
            SELECT r.room_number
            FROM Rooms r
            WHERE r.type_id = %s AND r.status = 'Available'
            ORDER BY r.room_number ASC
            LIMIT 1
            FOR UPDATE
            """,
            (type_id,)
        )
        room_row = read_cur.fetchone()

        if not room_row:
            conn.rollback()
            flash('No available rooms for the selected type.', 'warning')
            return redirect(url_for('index'))

        assigned_room = room_row['room_number']

        # 3) Insert reservation
        write_cur.execute(
            """
            INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
            VALUES (%s, %s, %s, %s, %s, 'Booked')
            """,
            (session['user_id'], assigned_room, check_in, check_out, total_price)
        )

        # 4) Update room status to Occupied
        write_cur.execute(
            "UPDATE Rooms SET status = 'Occupied' WHERE room_number = %s",
            (assigned_room,)
        )

        conn.commit()
        if discount_multiplier < 1.0:
            flash(
                f"Success! Room {assigned_room} (type: {type_row['type_name']}) booked with discount. "
                f"Total: ${total_price}",
                'success'
            )
        else:
            flash(f"Success! Room {assigned_room} (type: {type_row['type_name']}) booked. Total: ${total_price}", 'success')

    except Exception as e:
        conn.rollback()
        flash(f'Error: {str(e)}', 'danger')
    finally:
        conn.close()

    return redirect(url_for('index'))


# ============================================
# Part 6: Manager Dashboard (Aggregation)
# Auto-complete past-stay reservations + richer KPIs + trend with counts
# ============================================
@app.route('/dashboard')
def dashboard():
    if 'user_name' not in session:
        return redirect(url_for('login'))

    # Strict Access Control
    if session.get('role') != 'Manager':
        flash('Access Denied: Managers only.', 'danger')
        return redirect(url_for('index'))

    conn = get_db_connection()

    # 1) Auto-complete: mark past-stay (check_out < today) as Completed
    #    Optional: release rooms that have no non-Completed reservations
    try:
        pre = conn.cursor()
        pre.execute("""
            UPDATE Reservations
            SET status = 'Completed'
            WHERE status = 'Booked' AND check_out_date < CURDATE()
        """)
        pre.execute("""
            UPDATE Rooms r
            SET r.status = 'Available'
            WHERE r.status = 'Occupied'
              AND NOT EXISTS (
                SELECT 1
                FROM Reservations res
                WHERE res.room_number = r.room_number
                  AND res.status <> 'Completed'
              )
        """)
        conn.commit()
        pre.close()
    except Exception:
        conn.rollback()

    cur = conn.cursor(dictionary=True)

    # KPI: revenue (Completed only)
    cur.execute("SELECT SUM(total_price) AS total_revenue FROM Reservations WHERE status='Completed'")
    total_revenue = cur.fetchone().get('total_revenue') or 0

    # KPI: average price
    cur.execute("SELECT AVG(price) AS avg_price FROM Room_Types")
    avg_price = round((cur.fetchone().get('avg_price') or 0), 2)

    # KPI: occupancy & availability
    cur.execute("""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN status='Occupied' THEN 1 ELSE 0 END) AS occupied,
            SUM(CASE WHEN status='Available' THEN 1 ELSE 0 END) AS available
        FROM Rooms
    """)
    rstats = cur.fetchone()
    total_rooms = int(rstats['total'] or 0)
    occupied_rooms = int(rstats['occupied'] or 0)
    available_rooms = int(rstats['available'] or 0)
    occupancy_rate = round((occupied_rooms / total_rooms * 100.0), 1) if total_rooms else 0.0

    # KPI: active bookings (Booked)
    cur.execute("SELECT COUNT(*) AS c FROM Reservations WHERE status='Booked'")
    active_bookings = int(cur.fetchone()['c'])

    # Popular room types
    cur.execute("""
        SELECT rt.type_name, COUNT(*) AS booking_count
        FROM Reservations res
        JOIN Rooms r ON res.room_number = r.room_number
        JOIN Room_Types rt ON r.type_id = rt.type_id
        GROUP BY rt.type_name
        ORDER BY booking_count DESC
    """)
    popular_rooms = cur.fetchall()


    # Revenue trend by month (Completed) — revenue + count, restricted to 2025-01..11
    cur.execute("""
        SELECT DATE_FORMAT(check_out_date, '%Y-%m') AS ym,  
               COUNT(*) AS cnt,
               SUM(total_price) AS total
        FROM Reservations
        WHERE status='Completed'
          AND check_out_date >= %s
          AND check_out_date < %s
        GROUP BY ym
        ORDER BY ym
    """, ('2025-01-01', '2025-12-01'))
    rev_rows = cur.fetchall()
    rev_labels = [row['ym'] for row in rev_rows]
    rev_values = [float(row['total'] or 0) for row in rev_rows]
    rev_counts = [int(row['cnt'] or 0) for row in rev_rows]

    # Status breakdown
    cur.execute("SELECT status, COUNT(*) AS c FROM Reservations GROUP BY status")
    srows = cur.fetchall()
    status_labels = [row['status'] for row in srows]
    status_values = [int(row['c']) for row in srows]

    # Recent bookings
    cur.execute("""
        SELECT res.reservation_id, res.status, res.total_price, res.check_in_date, res.check_out_date,
               CONCAT(g.first_name,' ',g.last_name) AS guest_name,
               r.room_number, rt.type_name
        FROM Reservations res
        JOIN Guests g ON res.guest_id = g.guest_id
        JOIN Rooms r ON res.room_number = r.room_number
        JOIN Room_Types rt ON r.type_id = rt.type_id
        ORDER BY res.reservation_id DESC
        LIMIT 6
    """)
    recent_bookings = cur.fetchall()

    # Obtain all room type information for use in displaying the price management list.
    cur.execute("SELECT * FROM Room_Types ORDER BY type_id")
    all_room_types = cur.fetchall()
    
    conn.close()

    return render_template(
        'dashboard.html',
        revenue=total_revenue,
        avg_price=avg_price,
        popular_rooms=popular_rooms,
        # KPIs
        total_rooms=total_rooms,
        occupied_rooms=occupied_rooms,
        available_rooms=available_rooms,
        occupancy_rate=occupancy_rate,
        active_bookings=active_bookings,
        # Charts
        rev_labels=rev_labels,
        rev_values=rev_values,
        rev_counts=rev_counts,
        status_labels=status_labels,
        status_values=status_values,
        # Lists
        recent_bookings=recent_bookings,
        # All room types for price management
        all_room_types=all_room_types
    )


# ============================================
# Part 7: Admin Actions (Update Price)
# ============================================
@app.route('/admin/update_price', methods=['POST'])
def update_price():
    # Strict Access Control
    if 'user_name' not in session or session.get('role') != 'Manager':
        flash('Access Denied.', 'danger')
        return redirect(url_for('index'))

    type_id = request.form.get('type_id')
    new_price = request.form.get('new_price')

    if not type_id or not new_price:
        flash('Invalid input.', 'danger')
        return redirect(url_for('dashboard'))

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Update the price in Room_Types
        cur.execute("UPDATE Room_Types SET price = %s WHERE type_id = %s", (new_price, type_id))
        conn.commit()
        
        conn.close()
        flash('Price updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating price: {str(e)}', 'danger')

    return redirect(url_for('dashboard'))


if __name__ == '__main__':
    app.run(debug=True)
