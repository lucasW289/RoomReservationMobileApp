const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const mysql = require('mysql');
const session = require('express-session');

// Create express app
const app = express();
app.use(cors());
app.use(bodyParser.json());

// Start the server
const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

// MySQL database connection
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'mobile',
});

// Connect to MySQL
db.connect(err => {
    if (err) {
        console.error('Database connection failed:', err.message);
        return;
    }
    console.log('Connected to the database.');
});

// Configure express-session
app.use(
    session({
        secret: 'your_session_secret',
        resave: false,
        saveUninitialized: true,
        cookie: {
            secure: false,
            maxAge: 86400000
        },
    })
);

// JWT secret
const JWT_SECRET = 'm0bile2Simple';

// Login route working
app.post('/auth/login', (req, res) => {
    const {
        username,
        password
    } = req.body;

    db.query('SELECT * FROM users WHERE username = ?', [username], (err, results) => {
        if (err) {
            // console.error('Database error:', err);
            return res.status(500).json({
                message: 'Server error'
            });
        }

        // console.log('Results from DB:', results);

        if (results.length === 0) {
            return res.status(401).json({
                message: 'Invalid credentials'
            });
        }

        const user = results[0];

        // Convert `user.password` to string
        const passwordIsValid = bcrypt.compareSync(password, user.password.toString());

        if (!passwordIsValid) {
            // console.log('Password mismatch for user:', username);
            return res.status(401).json({
                accessToken: null,
                message: 'Invalid credentials'
            });
        }

        const token = jwt.sign({
                id: user.user_id,
                role: user.role
            },
            JWT_SECRET, {
                expiresIn: 86400
            }
        );

        db.query('UPDATE users SET accessToken = ? WHERE user_id = ?', [token, user.user_id], (err) => {
            if (err) {
                // console.error('Error updating access token:', err);
                return res.status(500).json({
                    message: 'Failed to update access token'
                });
            }

            res.status(200).json({
                id: user.user_id,
                username: user.username,
                name: user.name,
                role: user.role,
                accessToken: token,
            });
        });
    });
});

// Signup route working
app.post('/auth/signup', (req, res) => {
    const {
        id,
        username,
        name,
        password,
        confirmPassword
    } = req.body;

    if (!id || !username || !name || !password || !confirmPassword) {
        return res.status(400).json({
            message: 'All fields are required.'
        });
    }

    if (password !== confirmPassword) {
        return res.status(400).json({
            message: 'Passwords do not match.'
        });
    }

    db.query('SELECT * FROM users WHERE user_id = ? OR username = ?', [id, username], (err, results) => {
        if (err) {
            // console.error('Database error:', err);
            return res.status(500).json({
                message: 'Server error'
            });
        }

        if (results.length > 0) {
            return res.status(400).json({
                message: 'ID or Username already exists.'
            });
        }

        const hashedPassword = bcrypt.hashSync(password, 8);

        const newUser = {
            user_id: id,
            username,
            name,
            password: hashedPassword,
            role: 'student',
            accessToken: null,
        };

        db.query('INSERT INTO users SET ?', newUser, (err) => {
            if (err) {
                // console.error('Error inserting new user:', err);
                return res.status(500).json({
                    message: 'Server error'
                });
            }

            const token = jwt.sign({
                    id: newUser.user_id,
                    role: newUser.role
                },
                JWT_SECRET, {
                    expiresIn: 86400
                }
            );

            db.query('UPDATE users SET accessToken = ? WHERE user_id = ?', [token, id], (err) => {
                if (err) {
                    // console.error('Error updating access token after signup:', err);
                    return res.status(500).json({
                        message: 'Failed to store access token'
                    });
                }

                res.status(201).json({
                    message: 'User registered successfully.',
                    user: {
                        id,
                        username,
                        name,
                        role: 'Student',
                        accessToken: token,
                    }
                });
            });
        });
    });
});


// Logout route

app.post('/auth/logout', (req, res) => {
    // Debug: Log the Authorization header to verify it’s received correctly
    // console.log('Authorization header:', req.headers['authorization']);

    // Extract the token from the Authorization header
    const token = req.headers['authorization']?.split(' ')[1]; // "Bearer <token>"

    if (!token) {
        return res.status(400).json({
            message: 'No token provided',
        });
    }

    // Verify the JWT token
    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(401).json({
                message: 'Invalid token',
            });
        }

        // Get the user_id from the decoded token
        const userId = decoded.id;

        // Check if the accessToken is already null
        db.query('SELECT accessToken FROM users WHERE user_id = ?', [userId], (err, results) => {
            if (err) {
                return res.status(500).json({
                    message: 'Failed to check token status',
                });
            }

            if (results.length === 0 || results[0].accessToken === null) {
                return res.status(400).json({
                    message: 'Already logged out or invalid user',
                });
            }

            // Nullify the accessToken in the database to log the user out
            db.query('UPDATE users SET accessToken = NULL WHERE user_id = ?', [userId], (err) => {
                if (err) {
                    return res.status(500).json({
                        message: 'Failed to clear access token from the database',
                    });
                }

                // Successfully logged out
                res.status(200).json({
                    message: 'Logout successful',
                });
            });
        });
    });
});
app.put('/user/update', (req, res) => {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) {
        return res.status(400).json({
            message: 'No token provided'
        });
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(401).json({
                message: 'Invalid token'
            });
        }

        const userId = decoded.id;
        const {
            username,
            name,
            newPassword
        } = req.body;

        // console.log('Received details:', { userId, username, name, newPassword });

        const updateUser = (hashedPassword = null) => {
            const query = hashedPassword ?
                'UPDATE users SET username = ?, name = ?, password = ? WHERE user_id = ?' :
                'UPDATE users SET name = ?, username = ? WHERE user_id = ?';
            const params = hashedPassword ? [username, name, hashedPassword, userId] : [name, username, userId];

            db.query(query, params, (err, results) => {
                if (err) {
                    // console.log('Database update error:', err);
                    return res.status(500).json({
                        message: 'Failed to update user details'
                    });
                }

                // Fetch updated user info
                db.query('SELECT username, name FROM users WHERE user_id = ?', [userId], (err, results) => {
                    if (err || results.length === 0) {
                        // console.log('Error fetching user details:', err);
                        return res.status(500).json({
                            message: 'Error fetching user details'
                        });
                    }

                    res.status(200).json({
                        message: 'Profile updated successfully',
                        user: results[0],
                    });
                });
            });
        };

        if (newPassword) {
            bcrypt.hash(newPassword, 10, (err, hashedPassword) => {
                if (err) {
                    // console.log('Error hashing password:', err);
                    return res.status(500).json({
                        message: 'Error hashing password'
                    });
                }
                updateUser(hashedPassword);
            });
        } else {
            updateUser();
        }
    });
});

// app.post('/auth/logout', (req, res) => {
//     // Get the access token from the Authorization header
//     const token = req.headers['authorization']?.split(' ')[1]; // "Bearer <token>"

//     if (!token) {
//         return res.status(400).json({
//             message: 'No token provided',
//         });
//     }

//     // Verify the JWT token
//     jwt.verify(token, JWT_SECRET, (err, decoded) => {
//         if (err) {
//             return res.status(401).json({
//                 message: 'Invalid token',
//             });
//         }

//         // Get the user_id from the decoded token
//         const userId = decoded.id;

//         // Check if the accessToken is already null
//         db.query('SELECT accessToken FROM users WHERE user_id = ?', [userId], (err, results) => {
//             if (err) {
//                 return res.status(500).json({
//                     message: 'Failed to check token status',
//                 });
//             }

//             if (results.length === 0 || results[0].accessToken === null) {
//                 return res.status(400).json({
//                     message: 'Already logged out or invalid user',
//                 });
//             }

//             // Nullify the accessToken in the database to log the user out
//             db.query('UPDATE users SET accessToken = NULL WHERE user_id = ?', [userId], (err) => {
//                 if (err) {
//                     return res.status(500).json({
//                         message: 'Failed to clear access token from the database',
//                     });
//                 }

//                 // Successfully logged out
//                 res.status(200).json({
//                     message: 'Logout successful',
//                 });
//             });
//         });
//     });
// });

// Endpoint to get information for a specific room by roomID
app.get('/rooms/:roomID', async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1]; // "Bearer <token>"

    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify the JWT token
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        const userRole = decoded.role;
        const roomID = parseInt(req.params.roomID);

        // Check if the token is valid in the database
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!user) {
            // Token is invalid or does not match the database record
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }



        // Fetch room info from the 'rooms' table
        const roomQueryResult = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM rooms WHERE room_id = ?', [roomID], (err, results) => {
                if (err) {
                    return reject(err);
                }
                resolve(results);
            });
        });

        if (roomQueryResult.length === 0) {
            return res.status(404).json({
                error: 'Room not found'
            });
        }

        const roomInfo = roomQueryResult[0];

        // Fetch slot data for the specific room from the 'slots' table
        const slotQueryResult = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM slots WHERE room_id = ?', [roomID], (err, results) => {
                if (err) {
                    return reject(err);
                }
                resolve(results);
            });
        });

        if (slotQueryResult.length === 0) {
            return res.status(404).json({
                error: 'No slots available for this room'
            });
        }

        // Return room and slot information
        return res.status(200).json({
            room: roomInfo,
            slots: slotQueryResult.map(slot => ({
                slot_id: slot.slot_id,
                time_range: slot.time_range,
                status: slot.status,
                user_id: slot.user_id,
                created_at: slot.created_at
            }))
        });

    } catch (error) {
        // console.error('Database or JWT verification error:', error);
        return res.status(500).json({
            error: 'An error occurred while fetching room or slot data'
        });
    }
});


// Endpoint to get all room lists (requires authentication)

app.get('/rooms/', async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    if (!accessToken) {
        // console.log('Error: Missing access token');
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        // console.log(`Decoded JWT: ${JSON.stringify(decoded)}`);

        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) {
                    // console.error('Database error checking user:', err);
                    return reject(err);
                }
                resolve(result);
            });
        });

        if (!user) {
            // console.log('Error: Invalid or expired token');
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        // console.log('User validated, fetching room data...');

        // Fetch room data from the database
        db.query('SELECT * FROM rooms', (err, roomResults) => {
            if (err) {
                // console.error('Database error (rooms):', err);
                return res.status(500).json({
                    error: 'An error occurred while fetching rooms from the database'
                });
            }

            // console.log(`Rooms fetched: ${JSON.stringify(roomResults)}`);

            if (roomResults.length === 0) {
                // console.log('No rooms available');
                return res.status(404).json({
                    error: 'No rooms available'
                });
            }

            db.query('SELECT rooms.*, slots.time_range, slots.status FROM rooms LEFT JOIN slots ON rooms.room_id = slots.room_id', (err, slotResults) => {
                if (err) {
                    // console.error('Database error (slots):', err);
                    return res.status(500).json({
                        error: `An error occurred while fetching slots from the database: ${err.message}`
                    });
                }

                // console.log(`Slots fetched: ${JSON.stringify(slotResults)}`);

                const roomsWithSlots = roomResults.map(room => {
                    const slots = slotResults.filter(slot => slot.room_id === room.room_id);

                    return {
                        roomID: room.room_id,
                        roomName: room.room_name,
                        capacity: room.room_capacity,
                        slots: slots.map(slot => ({
                            time: slot.time_range,
                            status: slot.status || 'available', // Default to 'available' if no status is provided
                        })),
                        wifi: room.is_wifi_available,
                        imagePath: room.image_url || ''
                    };
                });

                return res.status(200).json({
                    rooms: roomsWithSlots
                });
            });
        });


    } catch (error) {
        // console.error('JWT verification error:', error);
        return res.status(500).json({
            error: `An error occurred while processing the request: ${error.message}`
        });
    }
});




// // Endpoint to get all room lists (requires authentication)
// app.get('/rooms/', async (req, res) => {
//     const accessToken = req.headers['authorization']?.split(' ')[1]; // "Bearer <token>"

//     if (!accessToken) {
//         console.log('Error: Missing access token');
//         return res.status(401).json({
//             error: 'Missing access token'
//         });
//     }

//     try {
//         // Verify the JWT token and decode it
//         const decoded = await jwt.verify(accessToken, JWT_SECRET);
//         const userID = decoded.id;
//         console.log(`Decoded JWT: ${JSON.stringify(decoded)}`);

//         // Check if the token is still valid in the database
//         const [user] = await new Promise((resolve, reject) => {
//             db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
//                 if (err) {
//                     console.error('Database error checking user:', err);
//                     return reject(err);
//                 }
//                 resolve(result);
//             });
//         });

//         if (!user) {
//             console.log('Error: Invalid or expired token');
//             return res.status(401).json({
//                 error: 'Invalid or expired token. Please log in again.'
//             });
//         }

//         console.log('User validated, fetching room data...');

//         // Fetch room data from the database
//         db.query('SELECT * FROM rooms', (err, roomResults) => {
//             if (err) {
//                 console.error('Database error (rooms):', err);
//                 return res.status(500).json({
//                     error: 'An error occurred while fetching rooms from the database'
//                 });
//             }

//             console.log(`Rooms fetched: ${JSON.stringify(roomResults)}`);

//             if (roomResults.length === 0) {
//                 console.log('No rooms available');
//                 return res.status(404).json({
//                     error: 'No rooms available'
//                 });
//             }

//             // Fetch slot data from the database
//             db.query('SELECT * FROM slots', (err, slotResults) => {
//                 if (err) {
//                     console.error('Database error (slots):', err);
//                     return res.status(500).json({
//                         error: 'An error occurred while fetching slots from the database'
//                     });
//                 }

//                 console.log(`Slots fetched: ${JSON.stringify(slotResults)}`);

//                 // Group slots by roomID
//                 const roomsWithSlots = roomResults.map(room => {
//                     const slotsForRoom = slotResults.filter(slot => slot.room_id === room.room_id);

//                     return {
//                         roomID: room.room_id,
//                         roomName: room.room_name,
//                         capacity: room.room_capacity,
//                         slots: slotsForRoom.map(slot => ({
//                             slotID: slot.slot_id,
//                             timeRange: slot.time_range,
//                             status: slot.status,
//                             userID: slot.user_id,
//                             createdAt: slot.created_at
//                         }))
//                     };
//                 });

//                 console.log('Rooms with slots:', JSON.stringify(roomsWithSlots));

//                 // Return rooms with their associated slots
//                 return res.status(200).json({
//                     rooms: roomsWithSlots
//                 });
//             });
//         });

//     } catch (error) {
//         console.error('JWT verification error:', error);
//         return res.status(500).json({
//             error: 'An error occurred while processing the request'
//         });
//     }
// });


// POST endpoint to book a room
app.post('/rooms/:roomID/book', async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];
    const {
        slot_id
    } = req.body;

    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify JWT token
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;

        // Check if the token matches the one in the database
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!user) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        const roomID = parseInt(req.params.roomID);
        const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format

        // Check if the user has already booked a slot today in `booking_history`
        const [existingBooking] = await new Promise((resolve, reject) => {
            db.query(
                'SELECT * FROM booking_history WHERE user_id_booked = ? AND DATE(created_at) = ?',
                [userID, today],
                (err, results) => {
                    if (err) return reject(err);
                    resolve(results);
                }
            );
        });

        if (existingBooking) {
            return res.status(400).json({
                error: 'You have already booked a slot today. Only one booking is allowed per day.'
            });
        }

        // Retrieve room details to get the room name
        const [room] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM rooms WHERE room_id = ?', [roomID], (err, results) => {
                if (err) return reject(err);
                resolve(results);
            });
        });

        if (!room) {
            return res.status(404).json({
                error: 'Room not found'
            });
        }

        const roomName = room.room_name;

        // Check if the slot is free in the `slots` table
        const [slot] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM slots WHERE slot_id = ? AND room_id = ? AND status = ?', [slot_id, roomID, 'free'], (err, results) => {
                if (err) return reject(err);
                resolve(results);
            });
        });

        if (!slot) {
            return res.status(400).json({
                error: 'Slot is not available for booking or does not exist'
            });
        }

        // Update the slot status to "pending" and set `user_id` in the `slots` table
        await new Promise((resolve, reject) => {
            db.query('UPDATE slots SET status = ?, user_id = ?, created_at = NOW() WHERE slot_id = ?', ['pending', userID, slot_id], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Insert the booking into `booking_history` with the retrieved `roomName` and a "pending" decision status
        await new Promise((resolve, reject) => {
            db.query(
                'INSERT INTO booking_history (room_id, slot_id, room_name, user_id_booked, user_id_decision, decision_status, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())',
                [roomID, slot_id, roomName, userID, null, 'pending'], // `room_name` dynamically set
                (err, result) => {
                    if (err) return reject(err);
                    resolve(result);
                }
            );
        });

        return res.status(200).json({
            message: 'Slot successfully booked',
            slot_id: slot_id,
            room_id: roomID,
            room_name: roomName,
            user_id: userID,
            status: 'pending'
        });

    } catch (error) {
        // console.error('Booking error:', error);
        return res.status(500).json({
            error: 'An error occurred while booking the slot'
        });
    }
});

// Endpoint to get the latest/today's booking for a specific user
app.get('/bookings/currentbook', async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify JWT token to get the user ID
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        // Check if the token is valid in the database
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!user) {
            // Token is invalid or does not match the database record
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }
        // Get today's date in YYYY-MM-DD format
        const today = new Date().toISOString().split('T')[0];

        // Query booking history for today's booking by this user
        const booking = await new Promise((resolve, reject) => {
            db.query(
                'SELECT * FROM booking_history WHERE user_id_booked = ? AND DATE(created_at) = ?',
                [userID, today],
                (err, results) => {
                    if (err) return reject(err);
                    resolve(results[0]); // Return the first matching record, if any
                }
            );
        });

        // Check if a booking exists for today
        if (!booking) {
            return res.status(404).json({
                message: 'No booking found for today.'
            });
        }

        // Respond with the booking details
        return res.status(200).json({
            message: 'Booking found for today',
            booking: booking
        });

    } catch (error) {
        // console.error('Error fetching current booking:', error);
        return res.status(500).json({
            error: 'An error occurred while retrieving the current booking'
        });
    }
});

// Endpoint to get booking history for a user(student and approver), with optional date filtering
// app.get('/bookings/History', async (req, res) => {
//     const accessToken = req.headers['authorization']?.split(' ')[1];
//     const {
//         date
//     } = req.query.date ? req.query : req.body; // Get `date` from query or body

//     if (!accessToken) {
//         return res.status(401).json({
//             error: 'Missing access token'
//         });
//     }

//     try {
//         // Verify JWT token to get the user ID
//         const decoded = await jwt.verify(accessToken, JWT_SECRET);
//         const userID = decoded.id;

//         const [userT] = await new Promise((resolve, reject) => {
//             db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
//                 if (err) return reject(err);
//                 resolve(result);
//             });
//         });

//         if (!userT) {
//             // Token is invalid or does not match the database record
//             return res.status(401).json({
//                 error: 'Invalid or expired token. Please log in again.'
//             });
//         }
//         // Determine whether the user is a student or a lecturer
//         // Assuming we have a 'role' field in the user table, where 1 is 'student' and 2 is 'lecturer'.
//         const [user] = await new Promise((resolve, reject) => {
//             db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
//                 if (err) return reject(err);
//                 resolve(result);
//             });
//         });

//         if (!user) {
//             return res.status(404).json({
//                 error: 'User not found'
//             });
//         }

//         // Base query to fetch booking history
//         let query = 'SELECT * FROM booking_history WHERE ';
//         let queryParams = [];

//         // If the user is a student, check for `user_id_booked`, if a lecturer, check for `user_id_decision`
//         if (user.role === "Student") { // Student
//             query += 'user_id_booked = ?';
//             queryParams.push(userID);
//         } else if (user.role === "Lecturer") { // Lecturer
//             query += 'user_id_decision = ?';
//             queryParams.push(userID);
//         } else {
//             return res.status(400).json({
//                 error: 'Invalid user role'
//             });
//         }

//         // Apply date filter if provided
//         if (date) {
//             query += ' AND DATE(created_at) = ?';
//             queryParams.push(date);
//         }

//         // Execute the query with or without the date filter
//         const bookings = await new Promise((resolve, reject) => {
//             db.query(query, queryParams, (err, results) => {
//                 if (err) return reject(err);
//                 resolve(results);
//             });
//         });

//         // Check if bookings are found
//         if (bookings.length === 0) {
//             return res.status(404).json({
//                 message: 'No bookings found for the specified criteria.'
//             });
//         }

//         // Return the booking history
//         return res.status(200).json({
//             message: 'Booking history retrieved successfully',
//             bookings: bookings
//         });

//     } catch (error) {
//         console.error('Error fetching booking history:', error);
//         return res.status(500).json({
//             error: 'An error occurred while retrieving the booking history'
//         });
//     }
// });


app.get('/bookings/History', async (req, res) => {
    // Extract the access token from the Authorization header
    const accessToken = req.headers['authorization']?.split(' ')[1]; // "Bearer <access-token>"

    // If there's no access token, return a 401 Unauthorized error
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Decode and verify the JWT token using the secret key
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id; // Get the user ID from the decoded token

        // Check the user in the database based on their ID and the access token
        const [userT] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // If no user is found, token might be invalid or expired
        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        // Fetch user's role and name
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role, name FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!user) {
            return res.status(404).json({
                error: 'User not found'
            });
        }

        // Base query to fetch booking history with a join on the slots table to get the time_range
        let query = `
            SELECT bh.*, s.time_range, bh.room_id
            FROM booking_history bh
            LEFT JOIN slots s ON bh.slot_id = s.slot_id
            WHERE `;
        let queryParams = [];

        // Depending on the user's role, query the booking history accordingly
        if (user.role === "Student") { // Student role
            query += 'bh.user_id_booked = ?';
            queryParams.push(userID);
        } else if (user.role === "Lecturer") { // Lecturer role
            query += 'bh.user_id_decision = ?';
            queryParams.push(userID);
        } else {
            return res.status(400).json({
                error: 'Invalid user role'
            });
        }

        // Optional: Apply a date filter if provided or if 'today' query param is passed
        const {
            date,
            today
        } = req.query; // Get `date` and `today` from query params

        if (today) {
            // Use today's date (formatted as YYYY-MM-DD)
            const todayDate = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format
            query += ' AND DATE(bh.created_at) = ?';
            queryParams.push(todayDate);
        } else if (date) {
            query += ' AND DATE(bh.created_at) = ?';
            queryParams.push(date);
        }

        // Execute the query to fetch booking history
        const bookings = await new Promise((resolve, reject) => {
            db.query(query, queryParams, (err, results) => {
                if (err) return reject(err);
                resolve(results);
            });
        });

        const mappedBookings = await Promise.all(bookings.map(async (booking) => {
            let decisionMakerName = 'Lect';
            let bookedByName = 'Unknown User'; // Default value for user_id_booked name

            // Fetch decision maker's name
            if (booking.user_id_decision) {
                const [decisionMaker] = await new Promise((resolve, reject) => {
                    db.query('SELECT name FROM users WHERE user_id = ?', [booking.user_id_decision], (err, result) => {
                        if (err) return reject(err);
                        resolve(result);
                    });
                });
                if (decisionMaker && decisionMaker.name) {
                    decisionMakerName = decisionMaker.name;
                }
            }

            // Fetch name of the user who booked (user_id_booked)
            if (booking.user_id_booked) {
                const [bookedBy] = await new Promise((resolve, reject) => {
                    db.query('SELECT name FROM users WHERE user_id = ?', [booking.user_id_booked], (err, result) => {
                        if (err) return reject(err);
                        resolve(result);
                    });
                });
                if (bookedBy && bookedBy.name) {
                    bookedByName = bookedBy.name;
                }
            }

            // Fetch room details
            const [roomDetails] = await new Promise((resolve, reject) => {
                db.query('SELECT room_capacity, is_wifi_available, image_url FROM rooms WHERE room_id = ?', [booking.room_id], (err, result) => {
                    if (err) return reject(err);
                    resolve(result);
                });
            });

            const roomCapacity = roomDetails && roomDetails.room_capacity ? roomDetails.room_capacity.toString() : 'N/A';
            const isWifiAvailable = roomDetails && roomDetails.is_wifi_available ? 'Free Wifi' : 'No Wifi';
            const imageUrl = roomDetails && roomDetails.image_url ? roomDetails.image_url : 'default_image_url_here';

            // Set the status based on the booking decision status
            let status = '';
            if (booking.decision_status === 'approved') {
                status = 'approved';
            } else if (booking.decision_status === 'rejected') {
                status = 'rejected';
            } else {
                status = 'pending'; // If neither approved nor rejected, set as pending
            }

            return {
                roomName: booking.room_name || 'Unknown Room',
                status: status, // Use the status variable here
                decisionMakerName: decisionMakerName,
                bookedByName: bookedByName, // Include the bookedByName field
                bookingDate: booking.created_at ? new Date(booking.created_at).toLocaleDateString() : '',
                bookingTime: booking.time_range || 'TBA',
                capacity: roomCapacity,
                wifi: isWifiAvailable,
                imageUrl: imageUrl, // New field for image URL
            };
        }));




        // If no bookings are found, return a 404
        if (mappedBookings.length === 0) {
            return res.status(404).json({
                message: 'No bookings found for the specified criteria.'
            });
        }

        // Send the bookings data in the response
        return res.status(200).json({
            message: 'Booking history retrieved successfully',
            bookings: mappedBookings
        });

    } catch (error) {
        // console.error('Error fetching booking history:', error);
        return res.status(500).json({
            error: 'An error occurred while retrieving the booking history'
        });
    }
});

app.get('/bookings/AllHistory', async (req, res) => {
    // Extract the access token from the Authorization header
    const accessToken = req.headers['authorization']?.split(' ')[1]; // "Bearer <access-token>"

    // If there's no access token, return a 401 Unauthorized error
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Decode and verify the JWT token using the secret key
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id; // Get the user ID from the decoded token

        // Verify the user's token in the database
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role, name FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // If no user is found, return an error
        if (!user) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        // Base query to fetch all booking history
        let query = `
            SELECT bh.*, s.time_range, bh.room_id
            FROM booking_history bh
            LEFT JOIN slots s ON bh.slot_id = s.slot_id
        `;
        let queryParams = [];

        // Optional: Apply a date filter if provided or if 'today' query param is passed
        const {
            date,
            today
        } = req.query; // Get `date` and `today` from query params

        if (today) {
            const todayDate = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format
            query += ' WHERE DATE(bh.created_at) = ?';
            queryParams.push(todayDate);
        } else if (date) {
            query += ' WHERE DATE(bh.created_at) = ?';
            queryParams.push(date);
        }

        // Execute the query to fetch booking history
        const bookings = await new Promise((resolve, reject) => {
            db.query(query, queryParams, (err, results) => {
                if (err) return reject(err);
                resolve(results);
            });
        });

        // Map the results to include additional details
        const mappedBookings = await Promise.all(bookings.map(async (booking) => {
            let decisionMakerName = 'Unknown';
            let bookedByName = 'Unknown';

            // Fetch decision maker's name
            if (booking.user_id_decision) {
                const [decisionMaker] = await new Promise((resolve, reject) => {
                    db.query('SELECT name FROM users WHERE user_id = ?', [booking.user_id_decision], (err, result) => {
                        if (err) return reject(err);
                        resolve(result);
                    });
                });
                if (decisionMaker && decisionMaker.name) {
                    decisionMakerName = decisionMaker.name;
                }
            }

            // Fetch name of the user who booked
            if (booking.user_id_booked) {
                const [bookedBy] = await new Promise((resolve, reject) => {
                    db.query('SELECT name FROM users WHERE user_id = ?', [booking.user_id_booked], (err, result) => {
                        if (err) return reject(err);
                        resolve(result);
                    });
                });
                if (bookedBy && bookedBy.name) {
                    bookedByName = bookedBy.name;
                }
            }

            // Fetch room details
            const [roomDetails] = await new Promise((resolve, reject) => {
                db.query('SELECT room_capacity, is_wifi_available, image_url FROM rooms WHERE room_id = ?', [booking.room_id], (err, result) => {
                    if (err) return reject(err);
                    resolve(result);
                });
            });

            const roomCapacity = roomDetails?.room_capacity?.toString() || 'N/A';
            const isWifiAvailable = roomDetails?.is_wifi_available ? 'Free Wifi' : 'No Wifi';
            const imageUrl = roomDetails?.image_url || 'default_image_url_here';

            // Determine the status of the booking
            const status = booking.decision_status === 'approved' ?
                'approved' :
                booking.decision_status === 'rejected' ?
                'rejected' :
                'pending';

            return {
                roomName: booking.room_name || 'Unknown Room',
                status,
                decisionMakerName,
                bookedByName,
                bookingDate: booking.created_at ? new Date(booking.created_at).toLocaleDateString() : '',
                bookingTime: booking.time_range || 'TBA',
                capacity: roomCapacity,
                wifi: isWifiAvailable,
                imageUrl,
            };
        }));

        // If no bookings are found, return a 404
        if (mappedBookings.length === 0) {
            return res.status(404).json({
                message: 'No bookings found for the specified criteria.'
            });
        }

        // Send the bookings data in the response
        return res.status(200).json({
            message: 'Booking history retrieved successfully',
            bookings: mappedBookings
        });

    } catch (error) {
        // console.error('Error fetching booking history:', error);
        return res.status(500).json({
            error: 'An error occurred while retrieving the booking history'
        });
    }
});


// POST route to add a room
app.post("/add", async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Validate JWT Token
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify JWT token to get the user ID
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        // Check if the token matches the user in the database
        const [userT] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }
        // Check if the user has the 'Staff' role
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!user || user.role !== 'Staff') {
            return res.status(403).json({
                error: 'Access denied. You must be a Staff member to add a room.'
            });
        }

        // Retrieve the room details from the request body
        const {
            name,
            ena,
            num,
            wifi,
            image
        } = req.body;

        // Validate the input
        if (!name || !ena || !num || !wifi || !image) {
            return res.status(400).send("All fields are required.");
        }

        // Check if a room with the same name already exists
        const [existingRoom] = await new Promise((resolve, reject) => {
            db.query('SELECT room_id FROM rooms WHERE room_name = ?', [name], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (existingRoom) {
            return res.status(409).json({
                error: `A room with the name '${name}' already exists. Please choose a different name.`
            });
        }

        // SQL query to insert a new room (without room_status)

        const wifi_status = wifi === "1" ? '1' : '0';
        // console.log("Wifi status: ", wifi_status);
        const roomValues = [name, num, wifi_status, image]; // Map the values accordingly
        const roomQuery = `INSERT INTO rooms (room_name, room_capacity, is_wifi_available, image_url) VALUES (?, ?, ?, ?)`;

        // Insert the room into the database
        db.query(roomQuery, roomValues, (err, result) => {
            if (err) {
                // console.error('Error inserting room:', err);
                return res.status(500).send('Error inserting room into database');
            }

            // Retrieve the ID of the inserted room
            const roomId = result.insertId;

            // Define slot status based on 'ena' value
            const slotStatus = ena === 'free' ? 'free' : 'disabled';
            const timeRanges = ['08:00-10:00', '10:00-12:00', '13:00-15:00', '15:00-17:00'];
            const slotsValues = timeRanges.map((time) => [roomId, time, slotStatus]);

            // SQL query to insert slots
            const slotsQuery = `INSERT INTO slots (room_id, time_range, status) VALUES ?`;

            // Insert slots for the new room
            db.query(slotsQuery, [slotsValues], (err) => {
                if (err) {
                    // console.error('Error inserting slots:', err);
                    return res.status(500).send('Error inserting slots into database');
                }

                res.send(`Room '${name}' added successfully with ID: ${roomId}, and 4 slots have been created with status: ${slotStatus}.`);
            });
        });

    } catch (error) {
        // console.error('Error verifying token:', error);
        return res.status(500).json({
            error: 'An error occurred while verifying the token'
        });
    }
});



// Dashboard Route
app.get('/dashboard', async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Check if access token is present
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify JWT token to get the user ID and role
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;

        // Check if the token matches the user in the database
        const [userT] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        // Fetch the user's role from the database
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Check if user has the required role
        if (!user || (user.role !== 'Staff' && user.role !== 'Lecturer')) {
            return res.status(403).json({
                error: 'Access denied. You must be a Staff or Lecturer to view the dashboard.'
            });
        }

        // Proceed with fetching dashboard data if the role is valid

        // Query for the total number of rooms
        const totalRoomsQuery = 'SELECT COUNT(*) AS totalRooms FROM rooms';
        const [totalRoomsResult] = await new Promise((resolve, reject) => {
            db.query(totalRoomsQuery, (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });
        const totalRooms = totalRoomsResult.totalRooms;

        // Query for the total number of slots
        const totalSlotsQuery = 'SELECT COUNT(*) AS totalSlots FROM slots';
        const [totalSlotsResult] = await new Promise((resolve, reject) => {
            db.query(totalSlotsQuery, (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });
        const totalSlots = totalSlotsResult.totalSlots;

        // Query for the count of slots by status
        const slotsByStatusQuery = `
            SELECT 
                status,
                COUNT(*) AS count
            FROM slots
            GROUP BY status
        `;

        const slotsByStatusResult = await new Promise((resolve, reject) => {
            db.query(slotsByStatusQuery, (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Parse the slot counts based on their status
        let freeSlots = 0,
            pendingSlots = 0,
            reservedSlots = 0,
            disabledSlots = 0;
        slotsByStatusResult.forEach(slot => {
            switch (slot.status) {
                case 'free':
                    freeSlots = slot.count;
                    break;
                case 'pending':
                    pendingSlots = slot.count;
                    break;
                case 'reserved':
                    reservedSlots = slot.count;
                    break;
                case 'disabled':
                    disabledSlots = slot.count;
                    break;
            }
        });

        // Send response with summary
        res.json({
            totalRooms,
            totalSlots,
            freeSlots,
            pendingSlots,
            reservedSlots,
            disabledSlots
        });

    } catch (error) {
        // console.error('Error verifying token or fetching dashboard data:', error);
        res.status(500).json({
            error: 'An error occurred while verifying the token or fetching dashboard data'
        });
    }
});

// PATCH or POST Endpoint to disable or free a specific time slot for a room
app.patch('/rooms/:roomID/:timeSlotID/toggle-status', async (req, res) => {
    const roomID = req.params.roomID;
    const timeSlotID = req.params.timeSlotID;
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Verify access token
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token',
        });
    }

    try {
        // Verify the JWT token to get the user ID and role
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;

        // Check if the token matches the user in the database
        const [userT] = await new Promise((resolve, reject) => {
            db.query(
                'SELECT * FROM users WHERE user_id = ? AND accessToken = ?',
                [userID, accessToken],
                (err, result) => {
                    if (err) return reject(err);
                    resolve(result);
                }
            );
        });

        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.',
            });
        }

        // Check the user's role
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Ensure the user is a Staff member
        if (!user || user.role !== 'Staff') {
            return res.status(403).json({
                error: 'Access denied. Only Staff members can modify a time slot.',
            });
        }

        // Check the current status of the slot
        const checkSlotSql = 'SELECT status FROM slots WHERE room_id = ? AND slot_id = ?';
        db.query(checkSlotSql, [roomID, timeSlotID], (err, results) => {
            if (err) {
                // console.error('Error checking slot status:', err);
                return res.status(500).send('Server error');
            }

            // Verify if the slot exists
            if (results.length === 0) {
                return res.status(404).send('Time slot not found');
            }

            const slotStatus = results[0].status;

            // Determine the next status based on the current status
            let newStatus;
            if (slotStatus === 'free') {
                newStatus = 'disabled'; // Change "free" to "disabled"
            } else if (slotStatus === 'disabled') {
                newStatus = 'free'; // Change "disabled" to "free"
            } else {
                return res.status(400).send('Only "free" or "disabled" slots can be toggled');
            }

            // Update the slot status in the database
            const updateSlotSql = 'UPDATE slots SET status = ? WHERE room_id = ? AND slot_id = ?';
            db.query(updateSlotSql, [newStatus, roomID, timeSlotID], (err, updateResults) => {
                if (err) {
                    // console.error('Error updating slot status:', err);
                    return res.status(500).send('Server error');
                }

                res.json({
                    message: `Slot '${timeSlotID}' in room '${roomID}' has been successfully updated to '${newStatus}'`,
                });
            });
        });
    } catch (error) {
        // console.error('Error verifying token or updating slot:', error);
        return res.status(500).json({
            error: 'An error occurred while verifying the token or updating the slot status',
        });
    }
});


//View Pending Requests
app.get("/bookings/pendingrequests", async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Verify access token
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify the JWT token to get the user ID and role
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        const [userT] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        // Check the user's role
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Ensure the user is a Lecturer
        if (!user || user.role !== 'Lecturer') {
            return res.status(403).json({
                error: 'Access denied. Only Lecturers can view pending bookings.'
            });
        }

        // Get today's date for comparison
        const today = new Date().toISOString().split('T')[0]; // Format: YYYY-MM-DD

        // Query to fetch pending bookings
        const query = `
            SELECT 
                bh.booking_id, 
                bh.room_id, 
                bh.slot_id, 
                bh.room_name, 
                bh.user_id_booked, 
                bh.decision_status, 
                bh.created_at AS booking_created_at,
                s.time_range, 
                r.image_url
            FROM booking_history bh
            JOIN slots s ON bh.slot_id = s.slot_id
            JOIN rooms r ON bh.room_id = r.room_id
            WHERE bh.decision_status = 'pending' AND DATE(bh.created_at) = ?
            ORDER BY bh.created_at ASC
        `;

        db.query(query, [today], (err, results) => {
            if (err) {
                // console.error('Error fetching pending bookings:', err);
                return res.status(500).json({
                    error: 'Server error while fetching pending bookings'
                });
            }

            if (results.length === 0) {
                return res.status(404).json({
                    message: 'No pending booking requests found for today'
                });
            }

            // Respond with the list of pending bookings
            res.json({
                message: 'Pending bookings fetched successfully',
                bookings: results
            });
        });

    } catch (error) {
        // console.error('Error verifying token or processing request:', error);
        return res.status(500).json({
            error: 'An error occurred while verifying the token or processing the request'
        });
    }
});






//Edit Room
app.patch("/rooms/:roomID/edit", async (req, res) => {
    const roomID = req.params.roomID;
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Verify access token
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify the JWT token to get the user ID and role
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        const [userT] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }
        // Check the user's role
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Ensure the user is a Staff member
        if (!user || user.role !== 'Staff') {
            return res.status(403).json({
                error: 'Access denied. Only Staff members can edit a room.'
            });
        }

        // Extract fields to update from the request body
        const {
            name,
            capacity,
            wifi,
            image
        } = req.body;

        // Validate input: ensure at least one field is provided
        if (!name && !capacity && !wifi && !image) {
            return res.status(400).send("At least one field (name, capacity, wifi, image) is required to update the room.");
        }

        // Build the SQL query dynamically based on provided fields
        let fields = [];
        let values = [];

        if (name) {
            fields.push("room_name = ?");
            values.push(name);
        }
        if (capacity) {
            fields.push("room_capacity = ?");
            values.push(capacity);
        }
        if (typeof wifi !== 'undefined') { // check if wifi is explicitly set
            fields.push("is_wifi_available = ?");
            values.push(wifi ? 1 : 0); // convert boolean to integer
        }
        if (image) {
            fields.push("image_url = ?");
            values.push(image);
        }

        values.push(roomID); // Add roomID at the end for WHERE clause

        const updateQuery = `UPDATE rooms SET ${fields.join(", ")} WHERE room_id = ?`;

        // Execute the update query
        db.query(updateQuery, values, (err, result) => {
            if (err) {
                // console.error('Error updating room:', err);
                return res.status(500).send('Server error while updating room');
            }

            // Check if any rows were affected
            if (result.affectedRows === 0) {
                return res.status(404).send('Room not found or no changes made');
            }

            res.send(`Room '${roomID}' updated successfully`);
        });

    } catch (error) {
        // console.error('Error verifying token or updating room:', error);
        return res.status(500).json({
            error: 'An error occurred while verifying the token or updating the room'
        });
    }
});

// Endpoint to update booking decision// Endpoint to update booking decision
app.patch("/bookings/decision/:bookingID", async (req, res) => {
    const bookingID = req.params.bookingID;
    const {
        decision
    } = req.body;
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Verify access token
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify the JWT token to get the user ID and role
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;
        const [userT] = await new Promise((resolve, reject) => {
            db.query('SELECT * FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!userT) {
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }
        // Check the user's role
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        // Ensure the user is a Lecturer
        if (!user || user.role !== 'Lecturer') {
            return res.status(403).json({
                error: 'Access denied. Only Lecturers can approve or disapprove bookings.'
            });
        }

        // Validate decision status parameter
        if (decision !== 'approved' && decision !== 'rejected') {
            return res.status(400).json({
                error: 'Invalid decision. Only "approved" or "rejected" are allowed.'
            });
        }

        // Fetch the booking details from the booking_history table for the specified bookingID
        const query = `
            SELECT slot_id, booking_id, decision_status 
            FROM booking_history 
            WHERE booking_id = ? AND decision_status = 'pending'`;

        db.query(query, [bookingID], async (err, results) => {
            if (err) {
                // console.error('Error fetching booking:', err);
                return res.status(500).json({
                    error: 'Server error while fetching booking'
                });
            }

            if (results.length === 0) {
                return res.status(404).json({
                    error: 'Booking not found or not in pending status.'
                });
            }

            const booking = results[0];

            // Update the decision status and user_id_decision in the booking_history table
            const updateBookingHistoryQuery = `
                UPDATE booking_history 
                SET decision_status = ?, user_id_decision = ? 
                WHERE booking_id = ?`;

            db.query(updateBookingHistoryQuery, [decision, userID, bookingID], (err, result) => {
                if (err) {
                    // console.error('Error updating booking history:', err);
                    return res.status(500).json({
                        error: 'Server error while updating booking history'
                    });
                }

                if (result.affectedRows === 0) {
                    return res.status(404).json({
                        error: 'Failed to update the booking history status'
                    });
                }

                // Now update the slot status based on the decision
                let updateSlotQuery;

                if (decision === 'approved') {
                    // If approved, set the slot status to 'reserved'
                    updateSlotQuery = `
                        UPDATE slots
                        SET status = 'reserved'
                        WHERE slot_id = ? AND status != 'disabled'
                    `;
                } else if (decision === 'rejected') {
                    // If rejected, set the slot status to 'free'
                    updateSlotQuery = `
                        UPDATE slots
                        SET status = 'free'
                        WHERE slot_id = ? AND status != 'disabled'
                    `;
                }

                db.query(updateSlotQuery, [booking.slot_id], (err, result) => {
                    if (err) {
                        // console.error('Error updating slot status:', err);
                        return res.status(500).json({
                            error: 'Server error while updating slot status'
                        });
                    }

                    if (result.affectedRows === 0) {
                        return res.status(404).json({
                            error: 'Failed to update the slot status'
                        });
                    }

                    // Successfully updated both booking history and slot status
                    res.json({
                        message: `Booking decision made, slot status set to "${decision === 'approved' ? 'reserved' : 'free'}".`,
                        bookingID,
                        newDecisionStatus: decision,
                        userIDDecision: userID,
                        slotStatus: decision === 'approved' ? 'reserved' : 'free'
                    });
                });
            });

        });

    } catch (error) {
        // console.error('Error verifying token or processing request:', error);
        return res.status(500).json({
            error: 'An error occurred while verifying the token or processing the request'
        });
    }
});

app.post("/end-of-day-reset", async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    // Verify access token
    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify the JWT token to get the user ID and role
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;

        // Check the user's role (only admins can perform this reset)
        const [user] = await new Promise((resolve, reject) => {
            db.query('SELECT role FROM users WHERE user_id = ?', [userID], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });



        // Update all slot statuses to 'free', excluding 'disabled' slots
        const updateSlotsQuery = `
            UPDATE slots
            SET status = 'free'
            WHERE status != 'disabled'
        `;
        db.query(updateSlotsQuery, (err, result) => {
            if (err) {
                // console.error('Error updating slot statuses:', err);
                return res.status(500).json({
                    error: 'Server error while resetting slot statuses'
                });
            }

            // Update all booking_history entries with 'pending' status to 'rejected'
            const updateBookingHistoryQuery = `
                UPDATE booking_history
                SET decision_status = 'rejected'
                WHERE decision_status = 'pending'
            `;
            db.query(updateBookingHistoryQuery, (err, result) => {
                if (err) {
                    // console.error('Error updating booking history:', err);
                    return res.status(500).json({
                        error: 'Server error while resetting booking history'
                    });
                }

                res.json({
                    message: 'End of day reset completed successfully. All slots have been set to free, and all pending bookings have been rejected.'
                });
            });
        });

    } catch (error) {
        // console.error('Error verifying token or processing request:', error);
        return res.status(500).json({
            error: 'An error occurred while verifying the token or processing the request'
        });
    }
});



// Endpoint to display username and id
app.get('/user/details', async (req, res) => {
    const accessToken = req.headers['authorization']?.split(' ')[1];

    if (!accessToken) {
        return res.status(401).json({
            error: 'Missing access token'
        });
    }

    try {
        // Verify JWT token to get the user ID
        const decoded = await jwt.verify(accessToken, JWT_SECRET);
        const userID = decoded.id;

        // Query to get username and id from the database
        const [userDetails] = await new Promise((resolve, reject) => {
            db.query('SELECT user_id, username FROM users WHERE user_id = ? AND accessToken = ?', [userID, accessToken], (err, result) => {
                if (err) return reject(err);
                resolve(result);
            });
        });

        if (!userDetails) {
            // Token is invalid or does not match the database record
            return res.status(401).json({
                error: 'Invalid or expired token. Please log in again.'
            });
        }

        // Respond with user details
        return res.status(200).json({
            message: 'User details retrieved successfully',
            user: {
                id: userDetails.user_id,
                username: userDetails.username
            }
        });

    } catch (error) {
        // console.error('Error retrieving user details:', error);
        return res.status(500).json({
            error: 'An error occurred while retrieving user details'
        });
    }
});