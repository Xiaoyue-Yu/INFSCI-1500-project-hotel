from flask import Flask, render_template, request, redirect, url_for, flash, session
import mysql.connector

app = Flask(__name__)
app.secret_key = 'super_secret_key'


db_config = {
    'user': 'root',
    'password': 'abcd', # Enter your local DB password here!
    'host': 'localhost',
    'database': 'hotel_project'
}


def get_db_connection():
    return mysql.connector.connect(**db_config)


# Part 1. front page
@app.route('/')
def index():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    sort_order = request.args.get('sort', 'default')

    query = """
        SELECT r.room_number, t.type_name, t.price, t.description 
        FROM Rooms r
        JOIN Room_Types t ON r.type_id = t.type_id
        WHERE r.status = 'Available'
    """

    if sort_order == 'price_asc':
        query += " ORDER BY t.price ASC"
    elif sort_order == 'price_desc':
        query += " ORDER BY t.price DESC"
    else:
        query += " ORDER BY r.room_number ASC"

    cursor.execute(query)
    rooms = cursor.fetchall()
    conn.close()

    user_name = session.get('user_name')

    return render_template('index.html', rooms=rooms, user_name=user_name)

# Part 2: log in
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':

        login_id = request.form['email']
        password = request.form['password']

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        query_guest = "SELECT * FROM Guests WHERE email = %s AND password = %s"
        cursor.execute(query_guest, (login_id, password))
        guest = cursor.fetchone()

        if guest:

            session['user_id'] = guest['guest_id']
            session['user_name'] = guest['first_name']
            session['role'] = 'Guest'  # 客人没有特殊权限

            conn.close()
            flash('Welcome back, Guest!', 'success')
            return redirect(url_for('index'))


        query_employee = "SELECT * FROM Employees WHERE username = %s AND password = %s"
        cursor.execute(query_employee, (login_id, password))
        employee = cursor.fetchone()

        conn.close()

        if employee:

            session['user_id'] = employee['employee_id']
            session['user_name'] = employee['username']
            session['role'] = employee['role']

            flash(f'Welcome Staff: {employee["username"]}', 'success')

            if employee['role'] == 'Manager':
                return redirect(url_for('dashboard'))
            else:
                return redirect(url_for('index'))

        else:
            flash('Invalid email/username or password', 'danger')
            return redirect(url_for('login'))

    return render_template('login.html')

# Part 3: log out
@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))


# ============================================
# Manager Dashboard (Aggregation Queries)
# ============================================
@app.route('/dashboard')
def dashboard():
    if 'user_name' not in session:
        return redirect(url_for('login'))

    if session.get('role') != 'Manager':
        flash('Access Denied: Managers only.', 'danger')
        return redirect(url_for('index'))

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    query_revenue = "SELECT SUM(total_price) as total_revenue FROM Reservations WHERE status = 'Completed'"
    cursor.execute(query_revenue)
    revenue_data = cursor.fetchone()

    # Handle case where no bookings exist yet (avoid None error)
    total_revenue = revenue_data['total_revenue'] if revenue_data['total_revenue'] else 0

    # --- Query 2: Most Popular Room Types (COUNT + GROUP BY) ---
    # "Which room type is booked the most?" (This is the Grouping requirement)
    query_popular = """
        SELECT rt.type_name, COUNT(*) as booking_count
        FROM Reservations res
        JOIN Rooms r ON res.room_number = r.room_number
        JOIN Room_Types rt ON r.type_id = rt.type_id
        GROUP BY rt.type_name
        ORDER BY booking_count DESC
    """
    cursor.execute(query_popular)
    popular_rooms = cursor.fetchall()

    # --- Query 3: Average Room Price (AVG) ---
    # "What is our average listing price?"
    query_avg = "SELECT AVG(price) as avg_price FROM Room_Types"
    cursor.execute(query_avg)
    avg_data = cursor.fetchone()
    avg_price = round(avg_data['avg_price'], 2) if avg_data['avg_price'] else 0

    conn.close()

    # Send all this data to the HTML
    return render_template('dashboard.html',
                           revenue=total_revenue,
                           popular_rooms=popular_rooms,
                           avg_price=avg_price)


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        first_name = request.form['first_name']
        last_name = request.form['last_name']
        email = request.form['email']
        phone = request.form['phone']
        password = request.form['password']

        conn = get_db_connection()
        cursor = conn.cursor()

        try:
            query = """
                INSERT INTO Guests (first_name, last_name, email, phone, password, tier_id, role)
                VALUES (%s, %s, %s, %s, %s, 2, 'Guest')
            """
            cursor.execute(query, (first_name, last_name, email, phone, password))
            conn.commit()
            flash('Registration successful! Please login.', 'success')
            return redirect(url_for('login'))
        except mysql.connector.Error as err:
            flash(f'Error: {err}', 'danger')
            return redirect(url_for('register'))
        finally:
            conn.close()

    return render_template('register.html')

if __name__ == '__main__':
    app.run(debug=True)